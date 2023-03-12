# Activity Classifier

Activity Classifier è un'applicazione mobile per Android costruita con il framework Flutter. L'applicazione consente di classificare l'attività fisica svolta dall'utente tramite il collegamento con un Arduino Nano 33 BLE Sense comunicando i dati acquisiti attraverso *Bluetooth Low Energy* (BLE).
Il dispositivo deve essere indossato verticalmente sulla coscia e connesso tramite una qualsiasi fonte di energia attraverso un cavo micro-USB (es. powerbank o smartphone in reverse charging).
Se il dispositivo è indossato correttamente, il classificatore riesce a distinguere con un'accuratezza su dati di validazione del 94% tra le seguenti attività:

- Fermo / Seduto
- Camminata
- Corsa

L'applicazione consente sia di raccogliere nuovi dataset per eseguire un nuovo addestramento offline (batch training) sia di classificare le attività con i dati ricevuti dalla board con un modello TensorFlow Lite installato nell'applicazione Android.
Il modello è stato realizzato utilizzando la libreria *Keras* che sfrutta le API di Tensorflow per la definizione e costruzione di reti neurali.