#include <Arduino_LSM9DS1.h>
#include <Arduino_HTS221.h>
#include <Arduino_APDS9960.h>
#include <ArduinoBLE.h>

int i = 0;


float old_temp = 0;
float old_hum = 0;

BLEService sportService("180A"); // BLE LED Service
BLECharCharacteristic dataCharacteristic("2A57", BLERead);



void setup() {
  // put your setup code here, to run once:

  Serial.begin(115200);
  while (!Serial);

  if (!BLE.begin()) {
    Serial.println("starting Bluetooth® Low Energy failed!");

    while (1);
  }

  BLE.setLocalName("Nano Suino");
  BLE.setAdvertisedService(sportService);

  // add the characteristic to the service
  sportService.addCharacteristic(dataCharacteristic);

  // add service
  BLE.addService(sportService);

  // set the initial value for the characteristic:
  dataCharacteristic.writeValue(0);

  // start advertising
  BLE.advertise();

  if (!IMU.begin()) {
    Serial.println("Failed to initialize IMU!");
    while (1);
  }

  if (!HTS.begin()) {
  Serial.println("Failed to initialize humidity temperature sensor!");  
  }

  if (!APDS.begin()) {
    Serial.println("Error initializing APDS9960 sensor.");
  }

}

void loop() {

  BLEDevice central = BLE.central();

  // accelerometer data
  float xa, ya, za;

  // gyroscope data
  float xg, yg, zg;

  // magnetometer data
  float xm, ym, zm;

  // read accelerometer data
  if (IMU.accelerationAvailable()) {
    IMU.readAcceleration(xa, ya, za);
  }

  // read gyroscope data
  if (IMU.gyroscopeAvailable()) {
    IMU.readGyroscope(xg, yg, zg);
  }

  // read magnetometer data
  IMU.readMagneticField(xm, ym, zm);



  // read temeprature and humidity

  float temperature = HTS.readTemperature();
  float humidity    = HTS.readHumidity();

  // check if the range values in temperature are bigger than 0,5 ºC
  // and if the range values in humidity are bigger than 1%
  if (abs(old_temp - temperature) >= 0.5 || abs(old_hum - humidity) >= 1 )
  {
    old_temp = temperature;
    old_hum = humidity;
  }

  // read color

  int r, g, b;

  if(APDS.colorAvailable()) {
    APDS.readColor(r, g, b);
  }

  // print data

  char buffer[500];

  sprintf(buffer, "%.3f %.3f %.3f || %.3f %.3f %.3f || %.3f %.3f %.3f  || %.3f %.3f || %d %d %d",
  xa, ya, za, xg, yg, zg, xm, ym, zm, temperature, humidity, r, g, b);

  Serial.println(buffer);

  dataCharacteristic.writeValue(i);
  i++;

  delay(100);
  

}