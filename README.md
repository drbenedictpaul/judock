# juDock v1.0 - Installation and User Guide

This guide will walk you through the setup and execution of the juDock application on a Linux computer.

---

## Part 1: One-Time System Setup

Before using juDock for the first time, your system needs one required piece of software: **Docker**.

#### 1. Install Docker

Open a terminal and run the following command. This is for Ubuntu, Debian, or other compatible systems.

```bash
sudo apt-get update && sudo apt-get install docker.io
```

*(Note: If you are using Fedora, use `sudo dnf install docker`)*

#### 2. Add Your User to the Docker Group

This important step allows you to run the application without `sudo`.

```bash
sudo usermod -aG docker ${USER}
```

**CRITICAL:** You must **log out and log back in** for this change to take effect. A full restart of your computer also works.

#### 3. Verify Docker

After logging back in, run the following command to confirm Docker is working correctly:

```bash
docker run hello-world
```
You should see a "Hello from Docker!" message. If you do, you are ready to proceed.

---

## Part 2: Installing and Running juDock

You will perform these steps in the location where you downloaded the `juDock-v1.0-linux.tar.gz` file.

#### 1. Unpack the Application Package

This will create a new folder named `juDock-v1.0-linux`.

```bash
tar -xzvf juDock-v1.0-linux.tar.gz
```

#### 2. Open the Application Folder

In your terminal, navigate into the newly created folder.

```bash
cd juDock-v1.0-linux
```

#### 3. Load the juDock Environment (One-Time Setup)

Run the following command to load the application's environment into Docker. This may take a few moments.

```bash
docker load < judock_v1.tar.gz
```

#### 4. Run juDock

To start the application, run the launcher script:

```bash
./run_judock.sh
```
*(Note: If you get a "permission denied" error, run `chmod +x run_judock.sh` first and then try again.)*

The script will guide you from here. It will:
*   Confirm the setup of the `juDock_input` and `juDock_results` directories in your main Home folder (`~/`).
*   Ask you to press Enter when your files are in place.
*   Start the server.

Once the server is running, open your web browser and navigate to **http://localhost:8000** to begin your analysis.

#### 5. Stopping the Application

To shut down the server, return to the terminal where it is running and press **Ctrl+C**.
You may then close the browser window.
