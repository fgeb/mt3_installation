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

class MT3Inference:
    """Wrapper for MT3 model inference."""

    def __init__(self, checkpoint_path, model_type='mt3'):
        # Model Constants
        if model_type == 'ismir2021':
            num_velocity_bins = 127
            self.encoding_spec = note_sequences.NoteEncodingSpec
            self.inputs_length = 512
        elif model_type == 'mt3':
            num_velocity_bins = 1
            self.encoding_spec = note_sequences.NoteEncodingWithTiesSpec
            self.inputs_length = 256
        else:
            raise ValueError('unknown model_type: %s' % model_type)

        # Get the directory of this script
        script_dir = os.path.dirname(os.path.abspath(__file__))
        gin_files = [
            os.path.join(script_dir, 'mt3/gin/model.gin'),
            os.path.join(script_dir, f'mt3/gin/{model_type}.gin')
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
            'inputs': seqio.ContinuousFeature(dtype=tf.float32, rank=2),
            'targets': seqio.Feature(vocabulary=self.vocabulary),
        }

        # Create a T5X model
        self._parse_gin(gin_files)
        self.model = self._load_model()

        # Restore from checkpoint
        self.restore_from_checkpoint(checkpoint_path)

    @property
    def input_shapes(self):
        return {
            'encoder_input_tokens': (self.batch_size, self.inputs_length),
            'decoder_input_tokens': (self.batch_size, self.outputs_length)
        }

    def _parse_gin(self, gin_files):
        """Parse gin files used to train the model."""
        gin_bindings = [
            'from __gin__ import dynamic_registration',
            'from mt3 import vocabularies',
            'VOCAB_CONFIG=@vocabularies.VocabularyConfig()',
            'vocabularies.VocabularyConfig.num_velocity_bins=%NUM_VELOCITY_BINS'
        ]
        with gin.unlock_config():
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
            return self.model.predict_batch(params, batch, num_decodes=1, temperature=1.0)

        return partial_predict_fn

    def transcribe_audio(self, audio_samples, sample_rate=16000):
        """Transcribe audio samples to a NoteSequence."""
        # Convert audio to spectrogram
        spectrogram = spectrograms.audio_to_spectrogram(
            audio_samples, self.spectrogram_config)

        # Create input batch
        inputs = {
            'encoder_input_tokens': spectrogram[None, :self.inputs_length],
            'decoder_input_tokens': np.zeros((1, self.outputs_length), dtype=np.int32)
        }

        # Run inference
        predictions = self._predict_fn(self._train_state.params, inputs)

        # Decode predictions
        tokens = self.vocabulary.decode_tf(predictions[0]).numpy()
        tokens = tokens[:np.argmax(tokens == self.vocabulary.eos_id)]

        # Convert to NoteSequence
        est_ns = metrics_utils.event_predictions_to_ns(
            tokens=tokens,
            codec=self.codec,
            encoding_spec=self.encoding_spec)

        return est_ns

def main():
    parser = argparse.ArgumentParser(description='Run MT3 inference on an audio file')
    parser.add_argument('--audio_file', required=True, help='Path to input audio file')
    parser.add_argument('--output_file', required=True, help='Path to output MIDI file')
    parser.add_argument('--checkpoint_path', required=True, help='Path to model checkpoint')
    parser.add_argument('--model_type', default='mt3', choices=['mt3', 'ismir2021'],
                      help='Model type to use (mt3 or ismir2021)')
    parser.add_argument('--sample_rate', type=int, default=16000,
                      help='Sample rate for audio processing')

    args = parser.parse_args()

    # Load audio file
    audio_samples = note_seq.audio_io.wav_data_to_samples_librosa(
        args.audio_file, sample_rate=args.sample_rate)

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
