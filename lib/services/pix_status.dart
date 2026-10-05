bool pixStatusGrantsPremium(String status) {
  switch (status.toUpperCase()) {
    case 'RECEIVED':
    case 'CONFIRMED':
    case 'RECEIVED_IN_CASH':
      return true;
    default:
      return false;
  }
}
