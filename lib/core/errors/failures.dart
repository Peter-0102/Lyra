abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

class AudioPlaybackFailure extends Failure {
  const AudioPlaybackFailure(super.message);
}

class YouTubeFailure extends Failure {
  const YouTubeFailure(super.message);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
