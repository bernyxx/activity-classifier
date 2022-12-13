#include <Arduino_LSM9DS1.h>
#include <Arduino_HTS221.h>
#include <Arduino_APDS9960.h>
#include <ArduinoBLE.h>

int i = 0;


float old_temp = 0;
float old_hum = 0;

#define BLE_UUID_ENVIRONMENTAL_SENSING_SERVICE    "181A"
#define BLE_UUID_TEMPERATURE                      "2A6E"
#define BLE_UUID_HUMIDITY                         "2A6F"
#define BLE_UUID_PRESSURE                         "2A6D"
#define BLE_UUID_ACCELEROMETER_SERVICE            "1101"
#define BLE_UUID_ACCELEROMETER_X                  "2101"
#define BLE_UUID_ACCELEROMETER_Y                  "2102"
#define BLE_UUID_ACCELEROMETER_Z                  "2103"
#define BLE_UUID_GYROSCOPE_X                      "2201"
#define BLE_UUID_GYROSCOPE_Y                      "2202"
#define BLE_UUID_GYROSCOPE_Z                      "2203"
#define BLE_UUID_MAGNETOMETER_X                   "2301"
#define BLE_UUID_MAGNETOMETER_Y                   "2302"
#define BLE_UUID_MAGNETOMETER_Z                   "2303"

BLEService envSensing(BLE_UUID_ENVIRONMENTAL_SENSING_SERVICE); // BLE LED Service
BLEService envAccelerometer(BLE_UUID_ACCELEROMETER_SERVICE);
BLEFloatCharacteristic xAccel(BLE_UUID_ACCELEROMETER_X, BLERead | BLENotify);
BLEFloatCharacteristic yAccel(BLE_UUID_ACCELEROMETER_Y, BLERead | BLENotify);
BLEFloatCharacteristic zAccel(BLE_UUID_ACCELEROMETER_Z, BLERead | BLENotify);
BLEFloatCharacteristic xGyro(BLE_UUID_GYROSCOPE_X, BLERead | BLENotify);
BLEFloatCharacteristic yGyro(BLE_UUID_GYROSCOPE_Y, BLERead | BLENotify);
BLEFloatCharacteristic zGyro(BLE_UUID_GYROSCOPE_Z, BLERead | BLENotify);
BLEFloatCharacteristic xMagn(BLE_UUID_MAGNETOMETER_X, BLERead | BLENotify);
BLEFloatCharacteristic yMagn(BLE_UUID_MAGNETOMETER_Y, BLERead | BLENotify);
BLEFloatCharacteristic zMagn(BLE_UUID_MAGNETOMETER_Z, BLERead | BLENotify);
BLEFloatCharacteristic Tempe(BLE_UUID_TEMPERATURE, BLERead | BLENotify);
BLEFloatCharacteristic Humid(BLE_UUID_HUMIDITY, BLERead | BLENotify);



void setup() {
  // put your setup code here, to run once:

  Serial.begin(115200);
  while (!Serial);

  if (!BLE.begin()) {
    Serial.println("starting Bluetooth® Low Energy failed!");

    while (1);
  }

  BLE.setLocalName("Nano Suino");
  BLE.setAdvertisedService(envSensing);

  // add the characteristic to the service
  envAccelerometer.addCharacteristic(xAccel);
  envAccelerometer.addCharacteristic(yAccel);
  envAccelerometer.addCharacteristic(zAccel);
  envAccelerometer.addCharacteristic(xGyro);
  envAccelerometer.addCharacteristic(yGyro);
  envAccelerometer.addCharacteristic(zGyro);
  envAccelerometer.addCharacteristic(xMagn);
  envAccelerometer.addCharacteristic(yMagn);
  envAccelerometer.addCharacteristic(zMagn);
  envSensing.addCharacteristic(Tempe);
  envSensing.addCharacteristic(Humid);

  // add service
  BLE.addService(envSensing);
  BLE.addService(envAccelerometer);

  // set the initial value for the characteristic:
  xAccel.writeValue(0);
  yAccel.writeValue(0);
  zAccel.writeValue(0);
  xGyro.writeValue(0);
  yGyro.writeValue(0);
  zGyro.writeValue(0);
  xMagn.writeValue(0);
  yMagn.writeValue(0);
  zMagn.writeValue(0);  
  Tempe.writeValue(0);
  Humid.writeValue(0);

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

  xAccel.writeValue(xa);
  yAccel.writeValue(ya);
  zAccel.writeValue(za);
  xGyro.writeValue(xg);
  yGyro.writeValue(yg);
  zGyro.writeValue(zg);
  xMagn.writeValue(xm);
  yMagn.writeValue(ym);
  zMagn.writeValue(zm);
  Tempe.writeValue(temperature);
  Humid.writeValue(humidity);

  delay(100);
  

}