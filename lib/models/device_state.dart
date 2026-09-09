class DeviceState {
  final String name;
  final String macAddress;
  final bool isConnected;
  final int leftBattery;
  final int rightBattery;
  final int caseBattery;
  final bool isLeftCharging;
  final bool isRightCharging;
  final bool isCaseCharging;
  final bool isBeastModeActive;

  const DeviceState({
    this.name = 'boAt Airdopes 311 Plus',
    this.macAddress = 'Scanning...',
    this.isConnected = false,
    this.leftBattery = 85,
    this.rightBattery = 85,
    this.caseBattery = 90,
    this.isLeftCharging = false,
    this.isRightCharging = false,
    this.isCaseCharging = false,
    this.isBeastModeActive = false,
  });

  DeviceState copyWith({
    String? name,
    String? macAddress,
    bool? isConnected,
    int? leftBattery,
    int? rightBattery,
    int? caseBattery,
    bool? isLeftCharging,
    bool? isRightCharging,
    bool? isCaseCharging,
    bool? isBeastModeActive,
  }) {
    return DeviceState(
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      isConnected: isConnected ?? this.isConnected,
      leftBattery: leftBattery ?? this.leftBattery,
      rightBattery: rightBattery ?? this.rightBattery,
      caseBattery: caseBattery ?? this.caseBattery,
      isLeftCharging: isLeftCharging ?? this.isLeftCharging,
      isRightCharging: isRightCharging ?? this.isRightCharging,
      isCaseCharging: isCaseCharging ?? this.isCaseCharging,
      isBeastModeActive: isBeastModeActive ?? this.isBeastModeActive,
    );
  }
}
