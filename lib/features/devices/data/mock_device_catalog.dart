import 'package:flutter/material.dart';

import '../models/device_models.dart';

class MockDeviceCatalog {
  MockDeviceCatalog._();

  static const List<DeviceDefinition> devices = [
    DeviceDefinition(
      id: 'envirosense',
      name: 'EnviroSense',
      description:
          'Environmental monitoring for temperature, humidity and light.',
      icon: Icons.device_thermostat_rounded,
      variants: [
        DeviceVariant(
          id: 'envirosense_basic',
          name: 'Basic',
          description: 'Essential environmental monitoring.',
          sensors: [
            SensorDefinition(
              id: 'temperature',
              name: 'Temperature',
              value: '24.6',
              unit: '°C',
              status: SensorStatus.normal,
              trend: '+0.4°C',
              icon: Icons.thermostat_outlined,
            ),
            SensorDefinition(
              id: 'humidity',
              name: 'Humidity',
              value: '58',
              unit: '%',
              status: SensorStatus.good,
              trend: '-2%',
              icon: Icons.water_drop_outlined,
            ),
            SensorDefinition(
              id: 'light',
              name: 'Light',
              value: '720',
              unit: 'lux',
              status: SensorStatus.optimal,
              trend: '+35 lux',
              icon: Icons.light_mode_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'main_lighting',
              name: 'Main lighting',
              description: 'Control connected lighting.',
              icon: Icons.lightbulb_outline_rounded,
              type: ControlType.switchControl,
            ),
          ],
        ),
        DeviceVariant(
          id: 'envirosense_premium',
          name: 'Premium',
          description: 'Advanced environmental monitoring and control.',
          sensors: [
            SensorDefinition(
              id: 'temperature',
              name: 'Temperature',
              value: '24.6',
              unit: '°C',
              status: SensorStatus.normal,
              trend: '+0.4°C',
              icon: Icons.thermostat_outlined,
            ),
            SensorDefinition(
              id: 'humidity',
              name: 'Humidity',
              value: '58',
              unit: '%',
              status: SensorStatus.good,
              trend: '-2%',
              icon: Icons.water_drop_outlined,
            ),
            SensorDefinition(
              id: 'light',
              name: 'Light',
              value: '720',
              unit: 'lux',
              status: SensorStatus.optimal,
              trend: '+35 lux',
              icon: Icons.light_mode_outlined,
            ),
            SensorDefinition(
              id: 'co2',
              name: 'CO₂',
              value: '680',
              unit: 'ppm',
              status: SensorStatus.good,
              trend: '-25 ppm',
              icon: Icons.air_rounded,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'main_lighting',
              name: 'Main lighting',
              description: 'Control connected lighting.',
              icon: Icons.lightbulb_outline_rounded,
            ),
            ControlDefinition(
              id: 'ventilation',
              name: 'Ventilation',
              description: 'Control connected ventilation.',
              icon: Icons.air_rounded,
            ),
          ],
        ),
      ],
    ),

    DeviceDefinition(
      id: 'watersense',
      name: 'WaterSense',
      description: 'Water quality and tank monitoring.',
      icon: Icons.water_drop_rounded,
      variants: [
        DeviceVariant(
          id: 'watersense_basic',
          name: 'Basic',
          description: 'Essential water monitoring.',
          sensors: [
            SensorDefinition(
              id: 'water_temperature',
              name: 'Water temperature',
              value: '22.4',
              unit: '°C',
              status: SensorStatus.normal,
              trend: '+0.2°C',
              icon: Icons.thermostat_outlined,
            ),
            SensorDefinition(
              id: 'water_level',
              name: 'Water level',
              value: '78',
              unit: '%',
              status: SensorStatus.good,
              trend: '+3%',
              icon: Icons.water_rounded,
            ),
            SensorDefinition(
              id: 'tds',
              name: 'TDS',
              value: '184',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '-8 ppm',
              icon: Icons.science_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'water_pump',
              name: 'Water pump',
              description: 'Control the main water pump.',
              icon: Icons.water_rounded,
            ),
          ],
        ),
        DeviceVariant(
          id: 'watersense_premium',
          name: 'Premium',
          description: 'Advanced water quality and level monitoring.',
          sensors: [
            SensorDefinition(
              id: 'ph',
              name: 'pH',
              value: '7.2',
              unit: '',
              status: SensorStatus.optimal,
              trend: '+0.1',
              icon: Icons.science_outlined,
            ),
            SensorDefinition(
              id: 'turbidity',
              name: 'Turbidity',
              value: '1.8',
              unit: 'NTU',
              status: SensorStatus.good,
              trend: '-0.3',
              icon: Icons.opacity_rounded,
            ),
            SensorDefinition(
              id: 'tds',
              name: 'TDS',
              value: '184',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '-8 ppm',
              icon: Icons.science_outlined,
            ),
            SensorDefinition(
              id: 'ammonia',
              name: 'Ammonia',
              value: '0.04',
              unit: 'ppm',
              status: SensorStatus.optimal,
              trend: '-0.01',
              icon: Icons.warning_amber_outlined,
            ),
            SensorDefinition(
              id: 'water_temperature',
              name: 'Water temperature',
              value: '22.4',
              unit: '°C',
              status: SensorStatus.normal,
              trend: '+0.2°C',
              icon: Icons.thermostat_outlined,
            ),
            SensorDefinition(
              id: 'water_level',
              name: 'Water level',
              value: '78',
              unit: '%',
              status: SensorStatus.good,
              trend: '+3%',
              icon: Icons.water_rounded,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'water_pump',
              name: 'Water pump',
              description: 'Control the main water pump.',
              icon: Icons.water_rounded,
            ),
            ControlDefinition(
              id: 'inlet_valve',
              name: 'Inlet valve',
              description: 'Control the water inlet valve.',
              icon: Icons.water_damage_outlined,
            ),
          ],
        ),
      ],
    ),

    DeviceDefinition(
      id: 'gaschecker',
      name: 'GasChecker',
      description: 'Air quality and hazardous gas monitoring.',
      icon: Icons.air_rounded,
      variants: [
        DeviceVariant(
          id: 'gaschecker_standard',
          name: 'Standard',
          description: 'Essential gas monitoring.',
          sensors: [
            SensorDefinition(
              id: 'co2',
              name: 'CO₂',
              value: '720',
              unit: 'ppm',
              status: SensorStatus.good,
              trend: '-18 ppm',
              icon: Icons.co2_rounded,
            ),
            SensorDefinition(
              id: 'co',
              name: 'CO',
              value: '3',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '0 ppm',
              icon: Icons.air_rounded,
            ),
            SensorDefinition(
              id: 'voc',
              name: 'VOC',
              value: '0.18',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '-0.02',
              icon: Icons.science_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'exhaust_fan',
              name: 'Exhaust fan',
              description: 'Control connected exhaust ventilation.',
              icon: Icons.air_rounded,
            ),
          ],
        ),
        DeviceVariant(
          id: 'gaschecker_industrial',
          name: 'Industrial',
          description: 'Advanced industrial gas and safety monitoring.',
          sensors: [
            SensorDefinition(
              id: 'co2',
              name: 'CO₂',
              value: '720',
              unit: 'ppm',
              status: SensorStatus.good,
              trend: '-18 ppm',
              icon: Icons.co2_rounded,
            ),
            SensorDefinition(
              id: 'co',
              name: 'CO',
              value: '3',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '0 ppm',
              icon: Icons.air_rounded,
            ),
            SensorDefinition(
              id: 'nh3',
              name: 'NH₃',
              value: '0.02',
              unit: 'ppm',
              status: SensorStatus.optimal,
              trend: '0 ppm',
              icon: Icons.science_outlined,
            ),
            SensorDefinition(
              id: 'voc',
              name: 'VOC',
              value: '0.18',
              unit: 'ppm',
              status: SensorStatus.normal,
              trend: '-0.02',
              icon: Icons.science_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'exhaust_fan',
              name: 'Exhaust fan',
              description: 'Control connected exhaust ventilation.',
              icon: Icons.air_rounded,
            ),
            ControlDefinition(
              id: 'safety_alarm',
              name: 'Safety alarm',
              description: 'Trigger the connected safety alarm.',
              icon: Icons.warning_amber_rounded,
              type: ControlType.button,
            ),
          ],
        ),
      ],
    ),

    DeviceDefinition(
      id: 'powersense',
      name: 'PowerSense',
      description: 'Electrical usage and power quality monitoring.',
      icon: Icons.bolt_rounded,
      variants: [
        DeviceVariant(
          id: 'powersense_basic',
          name: 'Basic',
          description: 'Essential energy monitoring.',
          sensors: [
            SensorDefinition(
              id: 'voltage',
              name: 'Voltage',
              value: '231',
              unit: 'V',
              status: SensorStatus.normal,
              trend: '+1 V',
              icon: Icons.electric_bolt_outlined,
            ),
            SensorDefinition(
              id: 'current',
              name: 'Current',
              value: '4.8',
              unit: 'A',
              status: SensorStatus.good,
              trend: '-0.4 A',
              icon: Icons.bolt_outlined,
            ),
            SensorDefinition(
              id: 'power',
              name: 'Power',
              value: '1.1',
              unit: 'kW',
              status: SensorStatus.normal,
              trend: '-0.1 kW',
              icon: Icons.power_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'main_relay',
              name: 'Main relay',
              description: 'Control the connected power relay.',
              icon: Icons.power_settings_new_rounded,
            ),
          ],
        ),
      ],
    ),

    DeviceDefinition(
      id: 'firesense',
      name: 'FireSense',
      description: 'Fire, smoke and heat monitoring.',
      icon: Icons.local_fire_department_outlined,
      variants: [
        DeviceVariant(
          id: 'firesense_industrial',
          name: 'Industrial',
          description: 'Advanced fire and environmental safety monitoring.',
          sensors: [
            SensorDefinition(
              id: 'temperature',
              name: 'Temperature',
              value: '26.1',
              unit: '°C',
              status: SensorStatus.normal,
              trend: '+0.7°C',
              icon: Icons.thermostat_outlined,
            ),
            SensorDefinition(
              id: 'smoke',
              name: 'Smoke',
              value: '0',
              unit: 'ppm',
              status: SensorStatus.optimal,
              trend: '0 ppm',
              icon: Icons.smoke_free_rounded,
            ),
            SensorDefinition(
              id: 'heat',
              name: 'Heat index',
              value: '28.4',
              unit: '°C',
              status: SensorStatus.good,
              trend: '+0.4°C',
              icon: Icons.local_fire_department_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'fire_alarm',
              name: 'Fire alarm',
              description: 'Trigger the connected fire alarm.',
              icon: Icons.notifications_active_outlined,
              type: ControlType.button,
            ),
          ],
        ),
      ],
    ),

    DeviceDefinition(
      id: 'motionsense',
      name: 'MotionSense',
      description: 'Presence, motion and occupancy monitoring.',
      icon: Icons.motion_photos_on_rounded,
      variants: [
        DeviceVariant(
          id: 'motionsense_pro',
          name: 'Pro',
          description: 'Advanced motion and occupancy monitoring.',
          sensors: [
            SensorDefinition(
              id: 'occupancy',
              name: 'Occupancy',
              value: '6',
              unit: 'people',
              status: SensorStatus.normal,
              trend: '+2',
              icon: Icons.people_outline_rounded,
            ),
            SensorDefinition(
              id: 'motion',
              name: 'Motion',
              value: 'Active',
              unit: '',
              status: SensorStatus.good,
              trend: 'Detected',
              icon: Icons.directions_run_rounded,
            ),
            SensorDefinition(
              id: 'light',
              name: 'Ambient light',
              value: '420',
              unit: 'lux',
              status: SensorStatus.normal,
              trend: '+20 lux',
              icon: Icons.light_mode_outlined,
            ),
          ],
          controls: [
            ControlDefinition(
              id: 'area_lighting',
              name: 'Area lighting',
              description: 'Control connected area lighting.',
              icon: Icons.lightbulb_outline_rounded,
            ),
          ],
        ),
      ],
    ),
  ];

  static DeviceDefinition? deviceByTypeId(String deviceTypeId) {
    for (final device in devices) {
      if (device.id == deviceTypeId) {
        return device;
      }
    }

    return null;
  }
}
