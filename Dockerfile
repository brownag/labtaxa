# Reference: https://aboland.ie/Docker.html
# Build Steps:

# docker build -t brownag/labtaxa .
# docker push brownag/labtaxa:latest
# docker run -d -p 8787:8787 -e PASSWORD=mypassword -v ~/Documents:/home/rstudio/Documents -e ROOT=TRUE brownag/labtaxa
# Then open your web browser and navigate to `http://localhost:8787`. The default username is `rstudio` and the default password is `mypassword`.

FROM rocker/rstudio:4.5.2

# Build arguments for versioning and metadata
ARG BUILD_DATE
ARG VERSION=0.0.3
ARG DATA_VERSION

# OCI-compliant metadata labels
LABEL org.opencontainers.image.title="labtaxa"
LABEL org.opencontainers.image.description="USDA KSSL Lab Data Mart Snapshot - Reproducible Soil Database Access"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.source="https://github.com/brownag/labtaxa"
LABEL org.opencontainers.image.url="https://brownag.github.io/labtaxa"
LABEL org.opencontainers.image.vendor="Andrew Brown"
LABEL org.opencontainers.image.authors="Andrew Brown <andrew.g.brown@usda.gov>"

# Set up renv for reproducible package management
ENV RENV_VERSION=1.0.7
RUN R --slave -e "install.packages('renv', repos='https://cloud.r-project.org/')"

# Configure renv cache location for build optimization
ENV RENV_PATHS_CACHE=/renv/cache
RUN mkdir -p /renv/cache

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    cmake \ 
    pkg-config \
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
    libpci-dev \ 
    libabsl-dev

RUN wget https://download-installer.cdn.mozilla.net/pub/firefox/releases/109.0/linux-x86_64/en-US/firefox-109.0.tar.bz2
RUN tar -xjf firefox-*.tar.bz2
RUN mv firefox /opt
RUN ln -s /opt/firefox/firefox /usr/local/bin/firefox

# Copy renv files early to leverage Docker layer caching
# This allows renv::restore() layer to be cached if renv.lock hasn't changed
WORKDIR /tmp/labtaxa-renv
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

# Restore exact package versions from lockfile
# This replaces the old install2.r approach with reproducible package management
RUN R --slave -e "renv::restore()" && \
    rm -rf renv/library renv/staging

# Copy demo and install scripts
COPY misc/install.R /home/rstudio/
COPY misc/demo.R /home/rstudio/

# Return to root directory for repository operations
WORKDIR /

RUN git clone https://github.com/brownag/labtaxa

RUN mkdir /root/labtaxa_data
RUN mkdir -p /home/rstudio/.local/share/R/labtaxa/

RUN Rscript /home/rstudio/install.R
RUN rm /home/rstudio/install.R

RUN cp -r ./labtaxa /home/rstudio/labtaxa
RUN rm -r ./labtaxa
RUN cp -r ~/labtaxa_data/* /home/rstudio/.local/share/R/labtaxa/
RUN rm -r ~/labtaxa_data
RUN rm -r ~/Downloads

# Create metadata file for reproducibility tracking
RUN mkdir -p /home/rstudio && \
    echo "{ \
      \"build_date\": \"${BUILD_DATE}\", \
      \"data_version\": \"${DATA_VERSION}\", \
      \"r_version\": \"4.5.2\", \
      \"rocker_base\": \"rocker/rstudio:4.5.2\", \
      \"package_version\": \"${VERSION}\" \
    }" > /home/rstudio/.labtaxa-metadata.json && \
    cat /home/rstudio/.labtaxa-metadata.json

RUN chown -hR rstudio /home/rstudio /home/rstudio
