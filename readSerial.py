import sys
import time
import serial
import argparse
from alive_progress import alive_bar


help_message = "Script per salvare i valori di una porta seriale in un file csv"

parser = argparse.ArgumentParser(description=help_message)

parser.add_argument('-p', '--port', help="Serial Port", default="COM1")
parser.add_argument('-b', '--baud', help="Baud Rate", default=115200, type=int)
parser.add_argument('-o', '--output', help="Output Path", default="output")
parser.add_argument('-n', '--samples',
                    help="Number of Samples", default=100, type=int)
parser.add_argument('-f', '--frequency',
                    help="Sample Frequency", default=1, type=int)

args = parser.parse_args()

period = 1 / args.frequency
print('Avvio campionamento')
print(f'Frequenza: {args.frequency} Hz  | Periodo: {period} sec')


def read_value_and_write_to_file(bar):
    with serial.Serial(args.port, args.baud) as ser:
        line = ser.readline().decode('UTF-8')
        values = line.split()
        print(values)
        if len(values) > 0:
            for i in range(len(values)):
                if i == len(values) - 1:
                    file.write(f'{values[i]}\n')
                else:
                    file.write(f'{values[i]},')
            bar()
            return False
        else:
            return True


# apri il file
file = open(f"{args.output}.csv", "w")

# scrivi l'indice
file.write("xa,ya,za,xg,yg,zg,xm,ym,zm,temp,hum\n")

# orario d'inizio
start_time = time.time()

# attivo la barra per visualizzare il completamento
with alive_bar(args.samples) as bar:
    i = 0
    while(i < args.samples):
        error = read_value_and_write_to_file(bar)

        if error == False:
            i += 1

        # attendi: periodo meno il tempo computazione della funzione
        time.sleep(period - ((time.time() - start_time) % period))


file.close()
