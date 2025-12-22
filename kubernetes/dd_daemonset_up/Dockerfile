FROM ubuntu:latest

RUN apt-get update && apt install jq -y && apt install curl -y 

WORKDIR /apps

COPY ds_up.sh .

RUN chmod +x ds_up.sh
CMD ["sh", "ds_up.sh"]
