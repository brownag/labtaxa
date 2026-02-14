# syntax=docker/dockerfile:1.4
# Reference: https://aboland.ie/Docker.html
# Build Steps (requires BuildKit):

# Using docker buildx (recommended):
# docker buildx build -t brownag/labtaxa .

# Or with standard docker build:
# DOCKER_BUILDKIT=1 docker build -t brownag/labtaxa .

# Push to registry:
# docker push brownag/labtaxa:latest

# Run container:
# docker run -d -p 8787:8787 -e PASSWORD=mypassword -v ~/Documents:/home/rstudio/Documents -e ROOT=TRUE brownag/labtaxa
# Then open http://localhost:8787 (username: rstudio, password: mypassword)

# Version arguments
ARG R_VERSION=4.5.2
ARG FIREFOX_VERSION=140.7.0esr

FROM rocker/rstudio:${R_VERSION}

# Build arguments for versioning and metadata
ARG BUILD_DATE=unknown
ARG VERSION=0.0.3
ARG DATA_VERSION=unknown
ARG FIREFOX_VERSION

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
    libgit2-dev \
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
    libharfbuzz-dev \
    libudunits2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
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
    libabsl-dev \
    libsodium-dev

RUN wget https://download-installer.cdn.mozilla.net/pub/firefox/releases/${FIREFOX_VERSION}/linux-x86_64/en-US/firefox-${FIREFOX_VERSION}.tar.xz
RUN tar -xJf firefox-*.tar.xz
RUN mv firefox /opt
RUN ln -s /opt/firefox/firefox /usr/local/bin/firefox

# Copy renv files early to leverage Docker layer caching
# This allows renv::restore() layer to be cached if renv.lock hasn't changed
WORKDIR /tmp/labtaxa-renv
COPY DESCRIPTION DESCRIPTION
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/activate.R renv/activate.R

# Restore exact package versions from lockfile
# This replaces the old install2.r approach with reproducible package management
RUN R --slave -e "renv::restore()" && \
    R --slave -e "renv::install(c('remotes', 'Rcpp', 'terra', 'sf', 'ggplot2', 'tidyterra', 'rmarkdown', 'httr', 'hms'))" && \
    R --slave -e "renv::snapshot(type = 'all')" && \
    R --slave -e "renv::clean()" && \
    rm -rf renv/library renv/staging

# Copy modularized build scripts, plus .Rprofile and renv for renv activation
RUN cp /tmp/labtaxa-renv/renv.lock /home/rstudio/
COPY build/download-ldm.R /home/rstudio/
COPY build/download-osd.R /home/rstudio/
COPY build/cache-labtaxa.R /home/rstudio/
COPY build/demo.R /home/rstudio/
COPY .Rprofile /home/rstudio/.Rprofile
COPY renv /home/rstudio/renv

# Copy local repository (build context) instead of cloning from remote
WORKDIR /
COPY . ./labtaxa

RUN mkdir /root/labtaxa_data
RUN mkdir -p /home/rstudio/.local/share/R/labtaxa/

# Copy labtaxa before running build scripts
RUN cp -r /labtaxa /home/rstudio/labtaxa

# Change to /home/rstudio so .Rprofile is found and renv is activated
WORKDIR /home/rstudio

# Restore renv environment
RUN R --no-save < /dev/null -e "renv::restore()"

# Install labtaxa package so download scripts can load functions
RUN R --no-save < /dev/null -e "remotes::install_local('./labtaxa', repos = c('https://ncss-tech.r-universe.dev', getOption('repos')), dependencies = FALSE)"

# Download LDM snapshot (includes morphologic database via get_LDM_snapshot)
RUN --mount=type=cache,target=/home/rstudio/labtaxa_data \
    R --no-save < /dev/null -f download-ldm.R

# Download OSD and SC data
RUN --mount=type=cache,target=/home/rstudio/labtaxa_data \
    R --no-save < /dev/null -f download-osd.R

# Cache data as SoilProfileCollection objects and install package
RUN R --no-save < /dev/null -f cache-labtaxa.R

# Verify cached RDS files exist
RUN echo "Verifying cached RDS files:" && \
    ls -lh /home/rstudio/.local/share/R/labtaxa/ || echo "Cache directory not found"

# Clean up (cache mount persists between builds, final image doesn't include it)
RUN rm -rf /labtaxa && \
    rm -f /home/rstudio/download-ldm.R /home/rstudio/download-osd.R /home/rstudio/cache-labtaxa.R

# Create metadata file for reproducibility tracking
RUN mkdir -p /home/rstudio && \
    cat > /home/rstudio/.labtaxa-metadata.json <<EOF
{
  "build_date": "${BUILD_DATE}",
  "data_version": "${DATA_VERSION}",
  "r_version": "${R_VERSION}",
  "rocker_base": "rocker/rstudio:${R_VERSION}",
  "package_version": "${VERSION}"
}
EOF
cat /home/rstudio/.labtaxa-metadata.json

RUN chown -hR rstudio /home/rstudio /home/rstudio
