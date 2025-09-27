extension DateTimeExtension on DateTime {
  List<String> getSeason() {
    switch (month) {
      case 11:
      case 0:
      case 1:
        return ['winter'];
      case 2:
        return ['spring', 'winter'];
      case 3:
        return ['spring'];
      case 4:
        return ['spring', 'summer'];
      case 5:
      case 6:
      case 7:
        return ['summer'];
      case 8:
        return ['summer', 'fall'];
      case 9:
        return ['fall'];
      case 10:
        return ['fall', 'winter'];
    }
    return ['all'];
  }
}