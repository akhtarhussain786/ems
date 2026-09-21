# Face recognition model

Place the MobileFaceNet TensorFlow Lite model here as:

    assets/models/mobilefacenet.tflite

Expected properties (see `lib/services/face_embedding_service.dart`):

| Property     | Value                          |
|--------------|--------------------------------|
| Input        | 1 x 112 x 112 x 3, float32     |
| Input range  | normalised to -1..1            |
| Output       | 1 x N floats (N is 128 or 192) |
| Size         | roughly 4-5 MB                 |

The service reads the input and output shapes from the model at load time, so a
model with a different embedding length works without a code change — but every
employee enrolled on the old model must re-enrol, because embeddings from two
different models are not comparable. The server detects that case and lets those
employees through rather than locking them out, so swapping the model does not
strand anyone; it does, however, silently disable verification for them until
they re-enrol.

Until the file is added, `FaceEmbeddingService.isAvailable` stays false: the app
builds and runs, enrollment reports that face setup is unavailable, and
attendance is unaffected.
