class DeviceState {
  final String name;
  final String macAddress;
  final bool isConnected;
  final int leftBattery;
  final int rightBattery;
  final int caseBattery;
  final bool isBeastModeActive;

  const DeviceState({
    this.name = 'boAt Airdopes 311 Plus',
    this.macAddress = 'Disconnected',
    this.isConnected = false,
    this.leftBattery = 85,
    this.rightBattery = 85,
    this.caseBattery = 90,
    this.isBeastModeActive = false,
  });

  DeviceState copyWith({
    String? name,
    String? macAddress,
    bool? isConnected,
    int? leftBattery,
    int? rightBattery,
    int? caseBattery,
    bool? isBeastModeActive,
  }) {
    return DeviceState(
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      isConnected: isConnected ?? this.isConnected,
      leftBattery: leftBattery ?? this.leftBattery,
      rightBattery: rightBattery ?? this.rightBattery,
      caseBattery: caseBattery ?? this.caseBattery,
      isBeastModeActive: isBeastModeActive ?? this.isBeastModeActive,
    );
  }
}
