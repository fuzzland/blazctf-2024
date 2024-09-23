FROM ghcr.io/fuzzland/blaz-ctf-2024-server:latest

COPY --chown=user:user . /home/user/server/

# Set the working directory
WORKDIR /home/user/server

# Command to run the server using Uvicorn
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8080"]
