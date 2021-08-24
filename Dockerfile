FROM perl:5.34

LABEL org.opencontainers.image.title="MiSeq QC data upload"
LABEL org.opencontainers.image.url="https://github.com/cfe-lab/MiSeqQC"
LABEL org.opencontainers.image.authors="BC CfE in HIV/AIDS"

# Path to bind to RAW_DATA/MiSeq/runs. See other environment variables in Settings.pm.
ENV MISEQQC_RAW_DATA=/mnt/raw_data

# Example launch command:
# docker run -it --rm --env MISEQQC_DB_HOST --env MISEQQC_DB_SID \
#   --env MISEQQC_DB_USER --env MISEQQC_DB_PASSWORD \
#   --volume=/path/to/RAW_DATA/MiSeq/runs:/mnt/raw_data miseqqc_upload

RUN apt-get update -qq --fix-missing && \
    apt-get install -qq alien libaio1 rsync rlwrap && \
    wget -q https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-basiclite-21.3.0.0.0-1.x86_64.rpm && \
    wget -q https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-sqlplus-21.3.0.0.0-1.x86_64.rpm && \
    wget -q https://download.oracle.com/otn_software/linux/instantclient/213000/oracle-instantclient-devel-21.3.0.0.0-1.x86_64.rpm && \
    alien -i oracle-instantclient-basiclite-*.rpm && \
    alien -i oracle-instantclient-sqlplus-*.rpm && \
    alien -i oracle-instantclient-devel-*.rpm && \
    rm oracle-instantclient-basiclite-*.rpm && \
    rm oracle-instantclient-sqlplus-*.rpm && \
    rm oracle-instantclient-devel-*.rpm && \
    apt-get remove -qq alien && \
    apt-get autoremove -qq && \
    rm -rf /var/lib/apt/lists/*

RUN cpanm DBD::Oracle
RUN cpanm XML::Simple
RUN cpanm IPC::System::Simple File::Rsync POSIX::strptime Date::Format

WORKDIR /usr/src/MiSeqQCReport
COPY modules Settings.pm upload_QC_data_for_pending_miseq_runs.pl \
     /usr/src/MiSeqQCReport/

ENTRYPOINT [ "/usr/src/MiSeqQCReport/upload_QC_data_for_pending_miseq_runs.pl" ]
