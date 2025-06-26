#!/usr/bin/env python3

import os
import argparse
import numpy as np
import tensorflow.compat.v2 as tf
import gin
import jax
import librosa
import note_seq
import seqio
import t5
import t5x

from mt3 import metrics_utils
from mt3 import models
from mt3 import network
from mt3 import note_sequences
from mt3 import preprocessors
from mt3 import spectrograms
from mt3 import vocabularies


BASE_DIR = '/home/fredi/mt3_setup/mt3/mt3/'
GIN_DIR = os.path.join(BASE_DIR, 'gin')

class MT3Inference:
    """Wrapper for MT3 model inference."""


    def __init__(self, checkpoint_path, model_type='mt3'):
        # Model Constants
        if model_type == 'ismir2021':
            num_velocity_bins = 127
            self.encoding_spec = note_sequences.NoteEncodingSpec
            self.inputs_length = 512
        elif model_type == 'ismir2022_base':
            num_velocity_bins = 1
            self.encoding_spec = note_sequences.NoteEncodingWithTiesSpec
            self.inputs_length = 256
        elif model_type == 'mt3':
            num_velocity_bins = 1
            self.encoding_spec = note_sequences.NoteEncodingWithTiesSpec
            self.inputs_length = 256
        else:
            raise ValueError('unknown model_type: %s' % model_type)

        # Get the directory of this script
        script_dir = os.path.dirname(os.path.abspath(__file__))

        # Set gin file paths based on model type
        if model_type == 'ismir2022_base':
            gin_files = [
                os.path.join(os.path.join(GIN_DIR, 'model.gin')),
                os.path.join(os.path.join(GIN_DIR, 'ismir2022', 'base.gin'))
            ]
        else:
            gin_files = [
                os.path.join(os.path.join(GIN_DIR, 'model.gin')),
                os.path.join(os.path.join(GIN_DIR, f'{model_type}.gin'))
            ]

        self.batch_size = 8
        self.outputs_length = 1024
        self.sequence_length = {
            'inputs': self.inputs_length,
            'targets': self.outputs_length
        }

        self.partitioner = t5x.partitioning.PjitPartitioner(num_partitions=1)

        # Build Codecs and Vocabularies
        self.spectrogram_config = spectrograms.SpectrogramConfig()
        self.codec = vocabularies.build_codec(
            vocab_config=vocabularies.VocabularyConfig(
                num_velocity_bins=num_velocity_bins))
        self.vocabulary = vocabularies.vocabulary_from_codec(self.codec)
        self.output_features = {
            'inputs': seqio.ContinuousFeature(dtype=np.float32, rank=2),
            'targets': seqio.Feature(vocabulary=self.vocabulary),
        }

        # Create a T5X model
        self._parse_gin(gin_files)
        self.model = self._load_model()

        # Debug: Print model configuration
        model_config = gin.get_configurable(network.T5Config)()
        print(f"Debug: Model config - num_encoder_layers: {model_config.num_encoder_layers}")
        print(f"Debug: Model config - num_decoder_layers: {model_config.num_decoder_layers}")
        print(f"Debug: Model config - d_model: {model_config.d_model}")
        print(f"Debug: Model config - num_heads: {model_config.num_heads}")
        print(f"Debug: Model config - d_kv: {model_config.d_kv}")
        print(f"Debug: Model config - d_ff: {model_config.d_ff}")

        # Inspect checkpoint structure
        self._inspect_checkpoint(checkpoint_path)

        # Restore from checkpoint
        self.restore_from_checkpoint(checkpoint_path)

        # Debug info
        print(f"Debug: Model type: {model_type}")
        print(f"Debug: Num velocity bins: {num_velocity_bins}")
        print(f"Debug: Encoding spec: {self.encoding_spec}")
        print(f"Debug: Codec num_classes: {self.codec.num_classes}")
        print(f"Debug: Vocabulary vocab_size: {self.vocabulary.vocab_size}")
        print(f"Debug: Vocabulary eos_id: {self.vocabulary.eos_id}")
        print(f"Debug: Vocabulary unk_id: {self.vocabulary.unk_id}")

    @property
    def input_shapes(self):
        return {
            'encoder_input_tokens': (self.batch_size, self.inputs_length),
            'decoder_input_tokens': (self.batch_size, self.outputs_length)
        }

    def _parse_gin(self, gin_files):
        """Parse gin files used to train the model."""
        # Get the directory of this script

        gin_bindings = [
            'from __gin__ import dynamic_registration',
            'from mt3 import vocabularies',
            'VOCAB_CONFIG=@vocabularies.VocabularyConfig()',
            'vocabularies.VocabularyConfig.num_velocity_bins=%NUM_VELOCITY_BINS'
        ]

        # Add additional bindings for ismir2022_base to include missing parameters
        if any('ismir2022/base.gin' in f for f in gin_files):
            gin_bindings.extend([
                'TASK_PREFIX = "mega_notes_ties"',
                'TASK_FEATURE_LENGTHS = {"inputs": 256, "targets": 1024}',
                'TRAIN_STEPS = 500000',
                'NUM_VELOCITY_BINS = 1',
                'PROGRAM_GRANULARITY = "full"',
                'ONSETS_ONLY = False',
                'USE_TIES = True'
            ])

        with gin.unlock_config():
            # Set the gin search path to include the mt3/gin directory
            gin.add_config_file_search_path(GIN_DIR)
            gin.parse_config_files_and_bindings(
                gin_files, gin_bindings, finalize_config=False)

    def _load_model(self):
        """Load up a T5X `Model` after parsing training gin config."""
        model_config = gin.get_configurable(network.T5Config)()
        module = network.Transformer(config=model_config)
        return models.ContinuousInputsEncoderDecoderModel(
            module=module,
            input_vocabulary=self.output_features['inputs'].vocabulary,
            output_vocabulary=self.output_features['targets'].vocabulary,
            optimizer_def=t5x.adafactor.Adafactor(decay_rate=0.8, step_offset=0),
            input_depth=spectrograms.input_depth(self.spectrogram_config))

    def _inspect_checkpoint(self, checkpoint_path):
        """Inspect checkpoint structure to understand model architecture."""
        try:
            import tensorflow as tf
            checkpoint = tf.train.load_checkpoint(checkpoint_path)
            var_to_shape_map = checkpoint.get_variable_to_shape_map()

            print(f"Debug: Checkpoint variables count: {len(var_to_shape_map)}")

            # Look for decoder layers
            decoder_layers = [k for k in var_to_shape_map.keys() if 'decoder' in k and 'layers_' in k]
            decoder_layers.sort()

            print(f"Debug: Decoder layers in checkpoint: {decoder_layers}")

            if decoder_layers:
                layer_numbers = []
                for layer in decoder_layers:
                    # Extract layer number from key like "decoder/layers_0/..."
                    parts = layer.split('/')
                    for part in parts:
                        if part.startswith('layers_'):
                            layer_num = int(part.split('_')[1])
                            layer_numbers.append(layer_num)
                            break

                layer_numbers = sorted(set(layer_numbers))
                print(f"Debug: Decoder layer numbers: {layer_numbers}")
                print(f"Debug: Number of decoder layers: {len(layer_numbers)}")

        except Exception as e:
            print(f"Debug: Could not inspect checkpoint: {e}")

    def restore_from_checkpoint(self, checkpoint_path):
        """Restore training state from checkpoint."""
        train_state_initializer = t5x.utils.TrainStateInitializer(
            optimizer_def=self.model.optimizer_def,
            init_fn=self.model.get_initial_variables,
            input_shapes=self.input_shapes,
            partitioner=self.partitioner)

        restore_checkpoint_cfg = t5x.utils.RestoreCheckpointConfig(
            path=checkpoint_path, mode='specific', dtype='float32')

        train_state_axes = train_state_initializer.train_state_axes
        train_state = train_state_initializer.from_checkpoint_or_scratch(
            [restore_checkpoint_cfg], init_rng=jax.random.PRNGKey(0))

        self._predict_fn = self._get_predict_fn(train_state_axes)
        self._train_state = train_state

    def _get_predict_fn(self, train_state_axes):
        """Get a function that runs inference."""
        def partial_predict_fn(params, batch):
            return self.model.predict_batch(params, batch)#, num_decodes=1, temperature=1.0)

        return partial_predict_fn

    def transcribe_audio(self, audio_samples, sample_rate=16000):
        """Transcribe audio samples to a NoteSequence."""
        print(f"Debug: Audio samples shape: {audio_samples.shape}")
        print(f"Debug: Audio samples dtype: {audio_samples.dtype}")
        print(f"Debug: Audio samples min/max: {audio_samples.min():.3f}/{audio_samples.max():.3f}")
        print(f"Debug: Sample rate: {sample_rate}")
        print(f"Debug: Input length: {self.inputs_length}")

        # Convert audio to spectrogram
        spectrogram = spectrograms.compute_spectrogram(
            audio_samples, self.spectrogram_config)

        print(f"Debug: Raw spectrogram shape: {spectrogram.shape}")
        print(f"Debug: Raw spectrogram dtype: {spectrogram.dtype}")

        # Convert TensorFlow tensor to NumPy array
        if hasattr(spectrogram, 'numpy'):
            spectrogram = spectrogram.numpy()
            print(f"Debug: Converted to NumPy array")

        print(f"Debug: Final spectrogram shape: {spectrogram.shape}")
        print(f"Debug: Final spectrogram dtype: {spectrogram.dtype}")
        print(f"Debug: Spectrogram min/max: {spectrogram.min():.3f}/{spectrogram.max():.3f}")

        # Process audio in overlapping chunks
        hop_size = self.inputs_length // 2  # 50% overlap
        total_frames = spectrogram.shape[0]
        predictions_list = []

        print(f"Debug: Total spectrogram frames: {total_frames}")
        print(f"Debug: Hop size: {hop_size}")

        for start_frame in range(0, total_frames, hop_size):
            end_frame = min(start_frame + self.inputs_length, total_frames)

            # If we don't have enough frames, pad with zeros
            if end_frame - start_frame < self.inputs_length:
                chunk = np.zeros((self.inputs_length, spectrogram.shape[1]), dtype=spectrogram.dtype)
                chunk[:end_frame - start_frame] = spectrogram[start_frame:end_frame]
            else:
                chunk = spectrogram[start_frame:end_frame]

            start_time = start_frame / self.spectrogram_config.frames_per_second

            print(f"Debug: Processing chunk {len(predictions_list)+1}: frames {start_frame}-{end_frame}, time {start_time:.2f}s")

            # Create input batch for this chunk
            inputs = {
                'encoder_input_tokens': chunk[None, :],
                'decoder_input_tokens': np.zeros((1, self.outputs_length), dtype=np.int32)
            }

            # Run inference
            predictions = self._predict_fn(self._train_state.params, inputs)

            # Decode predictions
            tokens = self.vocabulary.decode_tf(predictions[0]).numpy()

            # Find EOS token in the raw predictions (not decoded tokens)
            raw_predictions = predictions[0]
            eos_pos = np.argmax(raw_predictions == self.vocabulary.eos_id)

            # Only trim if we found a valid EOS token
            if eos_pos > 0:
                tokens = tokens[:eos_pos]

            if len(tokens) > 0:
                predictions_list.append({
                    'est_tokens': tokens,
                    'start_time': start_time,
                    'raw_inputs': audio_samples[start_frame * self.spectrogram_config.hop_width:
                                               end_frame * self.spectrogram_config.hop_width]
                })
                print(f"Debug: Chunk {len(predictions_list)}: {len(tokens)} tokens")
            else:
                print(f"Debug: Chunk {len(predictions_list)+1}: no tokens")

        print(f"Debug: Total chunks processed: {len(predictions_list)}")

        if not predictions_list:
            print("Debug: No valid predictions generated")
            # Return empty NoteSequence
            empty_ns = note_seq.NoteSequence()
            empty_ns.ticks_per_quarter = 220
            return empty_ns

        # Combine all predictions
        est_ns = metrics_utils.event_predictions_to_ns(
            predictions_list, codec=self.codec, encoding_spec=self.encoding_spec)

        print(f"Debug: NoteSequence result keys: {est_ns.keys()}")
        print(f"Debug: Number of notes: {len(est_ns['est_ns'].notes)}")
        print(f"Debug: Invalid events: {est_ns['est_invalid_events']}")
        print(f"Debug: Dropped events: {est_ns['est_dropped_events']}")

        if len(est_ns['est_ns'].notes) > 0:
            print(f"Debug: First note: pitch={est_ns['est_ns'].notes[0].pitch}, "
                  f"start={est_ns['est_ns'].notes[0].start_time:.3f}, "
                  f"end={est_ns['est_ns'].notes[0].end_time:.3f}")
            print(f"Debug: Last note: pitch={est_ns['est_ns'].notes[-1].pitch}, "
                  f"start={est_ns['est_ns'].notes[-1].start_time:.3f}, "
                  f"end={est_ns['est_ns'].notes[-1].end_time:.3f}")

        return est_ns['est_ns']

def main():
    parser = argparse.ArgumentParser(description='Run MT3 inference on an audio file')
    parser.add_argument('--audio_file', required=True, help='Path to input audio file')
    parser.add_argument('--output_file', required=True, help='Path to output MIDI file')
    parser.add_argument('--checkpoint_path', required=True, help='Path to model checkpoint')
    parser.add_argument('--model_type', default='mt3', choices=['mt3', 'ismir2021', 'ismir2022_base'],
                      help='Model type to use (mt3, ismir2021, or ismir2022_base)')
    parser.add_argument('--sample_rate', type=int, default=16000,
                      help='Sample rate for audio processing')

    args = parser.parse_args()

    print("Starting inference...")

    # Load audio file
    with open(args.audio_file, 'rb') as f:
        audio_bytes = f.read()

    audio_samples = note_seq.audio_io.wav_data_to_samples_librosa(
        audio_bytes, sample_rate=args.sample_rate)

    # Initialize model
    model = MT3Inference(args.checkpoint_path, args.model_type)

    # Run transcription
    print(f"Transcribing {args.audio_file}...")
    est_ns = model.transcribe_audio(audio_samples, args.sample_rate)

    # Save MIDI file
    note_seq.sequence_proto_to_midi_file(est_ns, args.output_file)
    print(f"Transcription saved to {args.output_file}")

if __name__ == '__main__':
    main()
