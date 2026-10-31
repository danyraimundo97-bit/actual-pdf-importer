/// Display name for a backend `bankId` (see backend_app/src/parsers).
String bankDisplayName(String bankId) => switch (bankId) {
  'activobank' => 'ActivoBank',
  'moey' => 'Moey',
  'traderepublic' => 'Trade Republic',
  'ai' => 'AI-parsed',
  _ => bankId,
};
