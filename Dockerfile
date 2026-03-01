FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# Install openssh-server, sudo, iproute2, python, perl
RUN apt-get update && \
    apt-get install -y openssh-server sudo iproute2 python3 python3-pip perl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the SSH script and key
COPY setup-ssh.sh /tmp/setup-ssh.sh
COPY stabl_key.pub /tmp/stabl_key.pub

# Run the SSH setup script
RUN chmod +x /tmp/setup-ssh.sh && \
    /tmp/setup-ssh.sh && \
    rm /tmp/setup-ssh.sh /tmp/stabl_key.pub

# Expose SSH port
EXPOSE 22

# Start the SSH daemon
CMD ["/usr/sbin/sshd", "-D"]
