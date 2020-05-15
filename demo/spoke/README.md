# Provision a "spoke" (managed) Cluster using OCM on AWS

## TODO Finish this readme

#### To provision a "spoke" cluster

run `./start.sh` from within this directory in your terminal... you will be prompted for input.

#### To cleanup a provisioned "spoke" cluster

run `kubctl delete -k .` form within this directory in your terminal.

#### to reset the yaml definition templates (so you can provision another "spoke" cluster)

run `./reset.sh` then open the `./local.rc` file and delete the `CLUSTER_NAME` variable...
run `./start.sh` again and you will be promted for a new cluster name. If you left all the other
vars in the `./local.rc` file you will not be prompted for values for them.