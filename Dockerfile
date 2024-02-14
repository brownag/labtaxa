# Reference: https://aboland.ie/Docker.html
# Build Steps:

# docker build -t brownag/labtaxa .
# docker push brownag/labtaxa:latest
# docker run -d -p 8787:8787 -e PASSWORD=mypassword -v ~/Documents:/home/rstudio/Documents -e ROOT=TRUE brownag/labtaxa
# Then open your web browser and navigate to `http://localhost:8787`. The default username is `rstudio` and the default password is `mypassword`.

FROM rocker/rstudio:latest

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libxml2 \
    git \
    build-essential \
    libproj-dev \
    libgdal-dev \
    libgeos-dev \
    gdal-bin \
    proj-bin \
    libxt-dev \
    libxml2-dev \
    libsqlite3-dev \
    libfribidi-dev \
    libudunits2-dev \
    default-jre \
    default-jdk \
    libcurl4-openssl-dev \
    wget \
    bzip2 \
    libxtst6 \
    libgtk-3-0 \
    libx11-xcb-dev \
    libdbus-glib-1-2 \
    libxt6 \
    libpci-dev

RUN wget https://download-installer.cdn.mozilla.net/pub/firefox/releases/109.0/linux-x86_64/en-US/firefox-109.0.tar.bz2
RUN tar -xjf firefox-*.tar.bz2
RUN mv firefox /opt
RUN ln -s /opt/firefox/firefox /usr/local/bin/firefox

RUN install2.r --error \
    --deps TRUE \
    devtools \
    Rcpp \
    terra \
    sf \
    ggplot2 \
    tidyterra \
    rmarkdown \
    httr
    
COPY misc/install.R /home/rstudio/
COPY misc/demo.R /home/rstudio/

RUN git clone https://github.com/brownag/labtaxa

RUN mkdir /root/labtaxa_data
RUN mkdir -p /home/rstudio/.local/share/R/labtaxa/

RUN Rscript /home/rstudio/install.R
RUN rm /home/rstudio/install.R

RUN cp -r ./labtaxa /home/rstudio/labtaxa
RUN cp -r ~/labtaxa_data/* /home/rstudio/.local/share/R/labtaxa/
RUN rm -r ./labtaxa
RUN rm -r /root/labtaxa_data
RUN rm -r ~/labtaxa_data
RUN rm -r ~/Downloads

RUN chown -hR rstudio /home/rstudio /home/rstudio
