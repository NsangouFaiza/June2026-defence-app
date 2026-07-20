String getDashboardRouteForRole(String role) {
  switch (role.toLowerCase()) {
    case 'donor':
      return '/donor-dashboard';
    case 'patient':
      return '/patient-dashboard';
    case 'hospital_staff':
    case 'blood_bank_staff':
      return '/hospital-dashboard';
    case 'system_admin':
    case 'blood_bank_admin':
      return '/admin-panel';
    default:
      return '/patient-dashboard';
  }
}
