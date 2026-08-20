/// Version de l'application, definie a un seul endroit.
///
/// Elle etait auparavant recopiee dans la barre superieure et dans le guide :
/// le badge annoncait encore v16 alors que le projet en etait a la v20.
const String kAppVersion = '0.38.0';

/// Forme courte affichee dans la barre superieure.
String get kAppVersionBadge => 'v${kAppVersion.split('.')[1]}';
