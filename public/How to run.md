🪟 Windows
Prerequisites: PowerShell 5.1+

Open PowerShell as Administrator (Right-click > Run as Administrator).

Admin rights are required to read CPU Temperatures.

Run the script:

PowerShell
 1- cd path\to\task-manager
   .\spy.ps1
2- cd path\to\task-manager
   docker-compose up --build


🐧 Linux
Prerequisites: bc (Basic Calculator) and docker

Install dependencies (Ubuntu/Debian):

Bash

sudo apt update && sudo apt install bc
Make the script executable and run it:

Bash

cd path/to/task-manager
chmod +x spy.sh
./spy.sh



🍎 macOS
Prerequisites: Standard Terminal

Make the script executable and run it:

Bash

cd path/to/task-manager
chmod +x spy_mac.sh
./spy_mac.sh

