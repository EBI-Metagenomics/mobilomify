#!/usr/bin/env nextflow
nextflow.enable.dsl=2

process AMRFINDER_REPORT {
    publishDir "$launchDir/$params.outdir/func_annot"

    container 'quay.io/microbiome-informatics/virify-python3:1.2'

    input:
        path amrfinder_tsv
	path mobilome_gff

    output:
	path("amr_location.txt")

    script:
    if(amrfinder_tsv.size() > 0)
        """    
	amr_report.py \
        --amr_out ${amrfinder_tsv} \
        --mobilome ${mobilome_gff} \
        """
}

