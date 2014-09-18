#!/bin/bash

# Configuration parameters
FEEDS_DOC="0AvrkbWHnoksNdGdYam4wX214SXpoRmdia0FEalZvUHc"
#JAVA_HOME="/usr"
JAVA_HOME="/usr/lib/jvm/java-6-openjdk-amd64"
JAVA_PARAMETERS="-server -Xmx3G"
#BUILDER_JAR="onebusaway-transit-data-federation-builder-1.1.11-SNAPSHOT-withAllDependencies.jar"

BUILDER_JAR="onebusaway-transit-data-federation-builder-1.1.11-SNAPSHOT-withAllDependencies-moblab.jar"

##########################

FEEDS_URL="https://docs.google.com/spreadsheet/pub?key=${FEEDS_DOC}&single=true&gid=0&output=csv"
TRANSFORMS_URL="https://docs.google.com/spreadsheet/pub?key=${FEEDS_DOC}&single=true&gid=1&output=csv"

JARS="jars"
WORKING_DIR="work"
INPUT_DIR="${WORKING_DIR}/inputs"
OUTPUT_DIR="${WORKING_DIR}/outputs"
INSPECT_DIR="${WORKING_DIR}/inspect"
CONFIG_DIR="config"

JAVA="${JAVA_HOME}/bin/java ${JAVA_PARAMETERS}"

FEED_INDEX="${CONFIG_DIR}/feeds.csv"
TRANSFORMS_INDEX="${CONFIG_DIR}/transforms.csv"

#Create input directory
mkdir -p $INPUT_DIR

#Clean working directories
rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR
rm -rf $INSPECT_DIR
mkdir -p $INSPECT_DIR

download_csv() {
    #Download file, remove first line, and add trailing newline if needed
    curl -sS $1 | tail -n +2 | sed -e '$a\' > $2
}

#Download CSV files with configuration parameters
download_csv $FEEDS_URL $FEED_INDEX
download_csv $TRANSFORMS_URL $TRANSFORMS_INDEX

#Download feeds
while IFS=, read NTD_ID FEED_URL
do
    FILE_NAME="${INPUT_DIR}/${NTD_ID}.zip"
    
    echo "Downloading $FEED_URL to $FILE_NAME"
    
    if [ -f $FILE_NAME ]; then
	CONDITIONAL="-z $FILE_NAME"
    else
	CONDITIONAL=""
    fi
    
    curl --compressed -L -o "$FILE_NAME" -R -sS $CONDITIONAL $FEED_URL
    
    mkdir "${INSPECT_DIR}/${NTD_ID}"
    unzip "$FILE_NAME" -d "${INSPECT_DIR}/${NTD_ID}"
done < $FEED_INDEX

#Fix Fairfax Connector with this one-liner

##unzip -p ${INPUT_DIR}/3068.zip google.log \
##| grep "did not match" \
##| sed "s/^.*TripId = \([0-9]*\).*$/{\"op\": \"remove\", \"match\": {\"class\": \"Trip\", \"id\": \"3068_\1\"} }/" \
##| sort \
##| uniq > ${CONFIG_DIR}/transforms/3068.json

#Transform feeds
while IFS=, read INPUT_AGENCY DEFAULT_AGENCY_ID OUTPUT_AGENCY
do
    TRANSFORM_FILE="${CONFIG_DIR}/transforms/${OUTPUT_AGENCY}.json"
    TRANSFORMER_INPUT="${INPUT_DIR}/${INPUT_AGENCY}.zip"
    TRANSFORMER_OUTPUT="${OUTPUT_DIR}/${OUTPUT_AGENCY}"
    echo "Running transformer with configuration ${TRANSFORM_FILE}"
    
    $JAVA -cp "${JARS}/*" org.onebusaway.gtfs_transformer.GtfsTransformerMain \
	--transform=$TRANSFORM_FILE \
	--agencyId $DEFAULT_AGENCY_ID \
	$TRANSFORMER_INPUT \
	$TRANSFORMER_OUTPUT
done < $TRANSFORMS_INDEX

#Remove bundle output directory
rm -rf "${WORKING_DIR}/bundle"

#Build bundle
$JAVA -jar $JARS/$BUILDER_JAR \
    "${CONFIG_DIR}/bundle.xml" "${WORKING_DIR}/bundle"

