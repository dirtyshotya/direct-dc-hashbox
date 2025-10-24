import json
import time
from Adafruit_ADS1x15 import ADS1115

# Initialize the ADC (ADS1115)
adc = ADS1115()

# Set the gain
GAIN = 1  # Available gains: 2/3, 1, 2, 4, 8, or 16

# Reference voltage for different gains
VREF = 4.096  # Reference voltage for GAIN = 1
MAX_ADC_VALUE = 32768.0  # For single-ended input, the range is 0 to 32767

# Update VREF based on the GAIN setting
if GAIN == 2/3:
    VREF = 6.144
elif GAIN == 1:
    VREF = 4.096
elif GAIN == 2:
    VREF = 2.048
elif GAIN == 4:
    VREF = 1.024
elif GAIN == 8:
    VREF = 0.512
elif GAIN == 16:
    VREF = 0.256

# Assuming a voltage divider with a 5:1 ratio
VOLTAGE_DIVIDER_RATIO = 5

def get_actual_voltage():
    # Read raw ADC value from channel 0
    raw_value = adc.read_adc(0, gain=GAIN)
    # Convert raw ADC value to voltage
    voltage = raw_value * (VREF / MAX_ADC_VALUE)
    # Scale the measured voltage according to the voltage divider ratio
    actual_voltage = voltage * VOLTAGE_DIVIDER_RATIO
    
    status = "Normal" if 10.0 <= actual_voltage <= 15.0 else "Alert"
    return {
        "voltage": f"{actual_voltage:.1f}V",
        "status": status
    }

def write_voltage_to_file(file_path):
    voltage_data = get_actual_voltage()
    with open(file_path, "w") as file:
        file.write(json.dumps(voltage_data))
    print(f"Voltage data written to {file_path}: {voltage_data}")

if __name__ == "__main__":
    file_path = "/home/100acresranch/voltage.txt"
    while True:
        write_voltage_to_file(file_path)
        time.sleep(1)  # Update every 2 seconds
