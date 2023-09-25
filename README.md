SmartThings Edge Driver for DAIKIN thermostat
================

The driver is built based on the DAIKIN thermonstat WiFi module BRP15B61.

The driver provide the following control:
- Mode switch between off, heat, cool, fan and dry
- Heating setpoint between 16 - 31 degree celsius
- Cooling setpoint between 17 - 32 degree celsius

The driver is communicating to the thermostat with the [unoffical API](https://github.com/SUPA-Nicholas/daikin-aricon-py#readme)

Things to work on
-----------------
- Adding auto mode
- Adding fan speed and direction control
- Hiding useless mode in the mode selection list

Credits
-------

Thanks to [ael-code](https://github.com/ael-code) for some useful [local API](https://github.com/ael-code/daikin-aricon-pylib)