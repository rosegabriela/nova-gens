How to run Nova script

chmod +x nova.sh
# simplest (uses default bucket novagens-data)
nohup ./nova.sh V1I4 & disown

# or specify a different bucket explicitly
nohup ./nova.sh V1I4 my-other-bucket & disown
