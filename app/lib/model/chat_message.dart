enum ChatDeliveryStatus {
  pending,
  sending,
  sent,
  delivered,
  read,
  failed;

  int get _rank => switch (this) {
    ChatDeliveryStatus.failed => 0,
    ChatDeliveryStatus.pending => 1,
    ChatDeliveryStatus.sending => 2,
    ChatDeliveryStatus.sent => 3,
    ChatDeliveryStatus.delivered => 4,
    ChatDeliveryStatus.read => 5,
  };

  /// Returns true if [next] is a forward progression over [this]
  /// (or a retry transition from failed/pending/sending).
  bool canAdvanceTo(ChatDeliveryStatus next) {
    if (this == next) return false;
    if (next == ChatDeliveryStatus.pending || next == ChatDeliveryStatus.sending || next == ChatDeliveryStatus.failed) {
      return _rank < ChatDeliveryStatus.sent._rank;
    }
    return next._rank > _rank;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.timestamp,
    required this.text,
    required this.status,
    this.kind = 'chat.message',
    this.attachmentSessionId,
    this.attachmentName,
    this.attachmentSize,
    this.attachmentCount,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final DateTime timestamp;
  final String text;
  final ChatDeliveryStatus status;
  final String kind;
  final String? attachmentSessionId;
  final String? attachmentName;
  final int? attachmentSize;
  final int? attachmentCount;

  bool get isAttachment => kind == 'chat.attachment' || attachmentSessionId != null;

  ChatMessage copyWith({
    ChatDeliveryStatus? status,
    String? attachmentSessionId,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    receiverId: receiverId,
    timestamp: timestamp,
    text: text,
    status: status ?? this.status,
    kind: kind,
    attachmentSessionId: attachmentSessionId ?? this.attachmentSessionId,
    attachmentName: attachmentName,
    attachmentSize: attachmentSize,
    attachmentCount: attachmentCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'receiverId': receiverId,
    'timestamp': timestamp.toUtc().millisecondsSinceEpoch,
    'text': text,
    'status': status.name,
    'kind': kind,
    if (attachmentSessionId != null) 'attachmentSessionId': attachmentSessionId,
    if (attachmentName != null) 'attachmentName': attachmentName,
    if (attachmentSize != null) 'attachmentSize': attachmentSize,
    if (attachmentCount != null) 'attachmentCount': attachmentCount,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    conversationId: json['conversationId'] as String,
    senderId: json['senderId'] as String,
    receiverId: json['receiverId'] as String,
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int, isUtc: true),
    text: json['text'] as String,
    status: ChatDeliveryStatus.values.firstWhere((value) => value.name == json['status'], orElse: () => ChatDeliveryStatus.failed),
    kind: (json['kind'] as String?) ?? 'chat.message',
    attachmentSessionId: json['attachmentSessionId'] as String?,
    attachmentName: json['attachmentName'] as String?,
    attachmentSize: (json['attachmentSize'] as num?)?.toInt(),
    attachmentCount: (json['attachmentCount'] as num?)?.toInt(),
  );
}
