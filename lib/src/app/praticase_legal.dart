class PratiCaseLegal {
  const PratiCaseLegal._();

  static const String privacyPolicyUrl = String.fromEnvironment(
    'PRIVACY_POLICY_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/privacy.html',
  );

  static const String termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/terms.html',
  );

  static const String studyTermsUrl = String.fromEnvironment(
    'STUDY_TERMS_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/study-terms.html',
  );

  static const String purchaseTermsUrl = String.fromEnvironment(
    'PURCHASE_TERMS_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/purchase-terms.html',
  );

  static const String distanceSalesUrl = String.fromEnvironment(
    'DISTANCE_SALES_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/distance-sales.html',
  );

  static const String refundPolicyUrl = String.fromEnvironment(
    'REFUND_POLICY_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/refund-policy.html',
  );

  static const String preliminaryInformationUrl = String.fromEnvironment(
    'PRELIMINARY_INFORMATION_URL',
    defaultValue:
        'https://praticase.medasi.com.tr/legal/preliminary-information.html',
  );

  static const String dataDeletionUrl = String.fromEnvironment(
    'DATA_DELETION_URL',
    defaultValue: 'https://praticase.medasi.com.tr/legal/data-deletion.html',
  );
}
