# Reference: https://aboland.ie/Docker.html
# Build Steps:

# docker build -t brownag/labtaxa .
# docker push brownag/labtaxa:latest
# docker run -d -p 8787:8787 -e PASSWORD=mypassword -v ~/Documents:/home/rstudio/ brownag/labtaxa
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

RUN git clone https://github.com/brownag/labtaxa

RUN mkdir labtaxa_data

RUN Rscript /home/rstudio/install.R

COPY --chown=rstudio --chmod=644 labtaxa/ /home/rstudio/labtaxa/

FROM builder AS databuild1
WORKDIR /root/.local/share/R/
COPY --from=1 --chown=rstudio --chmod=644 labtaxa/ /home/rstudio/.local/share/R/labtaxa/
