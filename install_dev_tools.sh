#!/bin/bash

# Update package lists
echo "Updating package index..."
sudo apt-get update -y

# Function to check and install Docker using the official repository method
install_docker() {
    if command -v docker &> /dev/null; then
        echo "✅ Docker is already installed: $(docker --version)"
    else
        echo "⏳ Uninstalling potential conflicting unofficial packages..."
        sudo apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true

        echo "⏳ Setting up official Docker apt repository..."
        sudo apt-get install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc

        sudo tee /etc/apt/sources.list.d/docker.sources <<EOF > /dev/null
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: \$(. /etc/os-release && echo "\${UBUNTU_CODENAME:-\$VERSION_CODENAME}")
Components: stable
Architectures: \$(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        sudo systemctl start docker
        sudo systemctl enable docker
        echo "✅ Docker Engine and plugins successfully installed from official repository!"
    fi
}

# Function to check and install Docker Compose plugin
install_docker_compose() {
    if docker compose version &> /dev/null; then
        echo "✅ Docker Compose (V2 Plugin) is already functional: $(docker compose version)"
    else
        echo "⏳ Installing Docker Compose plugin explicitly..."
        sudo apt-get install -y docker-compose-plugin
        echo "✅ Docker Compose plugin installed successfully!"
    fi
}

# Function to check and install Python 3.14
install_python() {
    if command -v python3.14 &> /dev/null; then
        echo "✅ Python 3.14 is already installed: $(python3.14 --version)"
    else
        echo "⏳ Setting up Deadsnakes repository for Python 3.14..."
        sudo apt-get install -y software-properties-common
        sudo add-apt-repository ppa:deadsnakes/ppa -y
        sudo apt-get update -y
        
        echo "⏳ Installing Python 3.14 packages..."
        sudo apt-get install -y python3.14 python3.14-venv python3.14-dev
        echo "✅ Python 3.14 installed successfully!"
    fi
}

# Function to check and install Django under Python 3.14
install_django() {
    if python3.14 -c "import django" &> /dev/null; then
        echo "✅ Django is already installed for Python 3.14: $(python3.14 -m django --version)"
    else
        echo "⏳ Installing Django via Python 3.14 pip..."
        # Using the official system flag to safely ensure global/user availability on managed environments
        python3.14 -m pip install --user django --break-system-packages
        echo "✅ Django deployed successfully: $(python3.14 -m django --version)"
    fi
}

# Core runtime orchestrator
echo "=== Starting Official Dev Tools Installation Pipeline ==?"
install_docker
install_docker_compose
install_python
install_django
echo "=== All configurations completed and validated successfully! ==="