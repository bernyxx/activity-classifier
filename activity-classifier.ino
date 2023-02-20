#include <Arduino_LSM9DS1.h>
#include <Arduino_HTS221.h>
#include <Arduino_APDS9960.h>
#include <ArduinoBLE.h>

float old_temp = 0;
float old_hum = 0;

// list of Characteristics UUIDs
#define BLE_UUID_ENVIRONMENTAL_SENSING_SERVICE "181A"
#define BLE_UUID_TEMPERATURE "2A6E"
#define BLE_UUID_HUMIDITY "2A6F"
#define BLE_UUID_PRESSURE "2A6D"
#define BLE_UUID_ACCELEROMETER_SERVICE "1101"
#define BLE_UUID_ACCELEROMETER_X "2101"
#define BLE_UUID_ACCELEROMETER_Y "2102"
#define BLE_UUID_ACCELEROMETER_Z "2103"
#define BLE_UUID_GYROSCOPE_X "2201"
#define BLE_UUID_GYROSCOPE_Y "2202"
#define BLE_UUID_GYROSCOPE_Z "2203"
#define BLE_UUID_MAGNETOMETER_X "2301"
#define BLE_UUID_MAGNETOMETER_Y "2302"
#define BLE_UUID_MAGNETOMETER_Z "2303"

// definition of the 2 services provided over BLE
BLEService sensingService(BLE_UUID_ENVIRONMENTAL_SENSING_SERVICE); // BLE LED Service
BLEService imuService(BLE_UUID_ACCELEROMETER_SERVICE);

// create the 11 characteristics (9 for the IMU + temperature and humidity readings)
// initialize each characteristic with the corrensponding UUID and make it only read and subscribable
BLEIntCharacteristic xAccel(BLE_UUID_ACCELEROMETER_X, BLERead | BLENotify);
BLEIntCharacteristic yAccel(BLE_UUID_ACCELEROMETER_Y, BLERead | BLENotify);
BLEIntCharacteristic zAccel(BLE_UUID_ACCELEROMETER_Z, BLERead | BLENotify);
BLEIntCharacteristic xGyro(BLE_UUID_GYROSCOPE_X, BLERead | BLENotify);
BLEIntCharacteristic yGyro(BLE_UUID_GYROSCOPE_Y, BLERead | BLENotify);
BLEIntCharacteristic zGyro(BLE_UUID_GYROSCOPE_Z, BLERead | BLENotify);
BLEIntCharacteristic xMagn(BLE_UUID_MAGNETOMETER_X, BLERead | BLENotify);
BLEIntCharacteristic yMagn(BLE_UUID_MAGNETOMETER_Y, BLERead | BLENotify);
BLEIntCharacteristic zMagn(BLE_UUID_MAGNETOMETER_Z, BLERead | BLENotify);

BLEIntCharacteristic Tempe(BLE_UUID_TEMPERATURE, BLERead | BLENotify);
BLEIntCharacteristic Humid(BLE_UUID_HUMIDITY, BLERead | BLENotify);

unsigned long previous_time = 0;

// accelerometer data
float xa, ya, za;

// gyroscope data
float xg, yg, zg;

// magnetometer data
float xm, ym, zm;

void setup()
{

  Serial.begin(115200);

  // start BLE service
  if (!BLE.begin())
  {
    Serial.println("starting Bluetooth® Low Energy failed!");

    while (1)
      ;
  }

  BLE.setLocalName("Nano Suino");

  BLE.setAdvertisedService(imuService);
  BLE.setAdvertisedService(sensingService);

  // add the characteristics to the accelerometer service
  imuService.addCharacteristic(xAccel);
  imuService.addCharacteristic(yAccel);
  imuService.addCharacteristic(zAccel);
  imuService.addCharacteristic(xGyro);
  imuService.addCharacteristic(yGyro);
  imuService.addCharacteristic(zGyro);
  imuService.addCharacteristic(xMagn);
  imuService.addCharacteristic(yMagn);
  imuService.addCharacteristic(zMagn);

  // add the characteristics to the sensing service
  sensingService.addCharacteristic(Tempe);
  sensingService.addCharacteristic(Humid);

  // add the services to the BLE device
  BLE.addService(imuService);
  BLE.addService(sensingService);

  // set the initial value for the characteristics
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

  // start advertising the board
  BLE.advertise();

  if (!IMU.begin())
  {
    Serial.println("Failed to initialize IMU!");
    while (1)
      ;
  }

  if (!HTS.begin())
  {
    Serial.println("Failed to initialize humidity temperature sensor!");
  }

  // if (!APDS.begin())
  // {
  //   Serial.println("Error initializing APDS9960 sensor.");
  // }
}

void loop()
{

  BLEDevice central = BLE.central();

  unsigned long now = millis();

  if (now - previous_time >= 75)
  {

    previous_time = now;

    // if (central)
    // {
    //   Serial.print("Connected to central: ");
    //   Serial.println(central.address());
    // }

    // read accelerometer data
    if (IMU.accelerationAvailable())
    {
      IMU.readAcceleration(xa, ya, za);
    }

    // read gyroscope data
    if (IMU.gyroscopeAvailable())
    {
      IMU.readGyroscope(xg, yg, zg);
    }

    // read magnetometer data
    if (IMU.magneticFieldAvailable())
    {
      IMU.readMagneticField(xm, ym, zm);
    }

    // read temeprature and humidity

    float temperature = HTS.readTemperature();
    float humidity = HTS.readHumidity();

    // check if the range values in temperature are bigger than 0,5 ºC
    // and if the range values in humidity are bigger than 1%
    if (abs(old_temp - temperature) >= 0.5 || abs(old_hum - humidity) >= 1)
    {
      old_temp = temperature;
      old_hum = humidity;
    }

    // read color
    // int r, g, b;

    // if (APDS.colorAvailable())
    // {
    //   APDS.readColor(r, g, b);
    // }

    // make every reading an integer to send over BLE

    int xa_int = xa * 1000;
    int ya_int = ya * 1000;
    int za_int = za * 1000;
    int xg_int = xg * 1000;
    int yg_int = yg * 1000;
    int zg_int = zg * 1000;
    int xm_int = xm * 1000;
    int ym_int = ym * 1000;
    int zm_int = zm * 1000;
    int temp_int = old_temp * 1000;
    int hum_int = old_hum * 1000;

    // print data on serial

    char buffer[500];

    sprintf(buffer, "%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
            xa, ya, za, xg, yg, zg, xm, ym, zm, old_temp, old_hum);

    Serial.println(buffer);

    // if something is connected to the board (via BLE) send the reading over BLE
    if (central.connected())
    {
      xAccel.writeValue(xa_int);
      yAccel.writeValue(ya_int);
      zAccel.writeValue(za_int);
      xGyro.writeValue(xg_int);
      yGyro.writeValue(yg_int);
      zGyro.writeValue(zg_int);
      xMagn.writeValue(xm_int);
      yMagn.writeValue(ym_int);
      zMagn.writeValue(zm_int);
      Tempe.writeValue(temp_int);
      Humid.writeValue(hum_int);
    }
  }
}