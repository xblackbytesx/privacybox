FROM debian:stable-slim

CMD ["date"]

RUN apt-get update -q && \
    apt-get install apt-transport-https -qy && \
    apt-get update -q && \
    apt-get install handbrake-cli -qy && \
    apt-get clean && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

VOLUME ["/input", "/output", "/config"]

ENTRYPOINT ["HandBrakeCLI"]

# Usage:
# docker build -t handbrake-cli .
# docker run --rm -v "$(pwd)"/config:/config -v "$(pwd)"/input:/input -v "$(pwd)"/output:/output handbrake-cli handbrake-cli --preset-import-file /config/x265.json -Z convert\ to\ x265 -i /input/input.mkv -o /output/output.mkv;