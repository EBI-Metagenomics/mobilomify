#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

/*
    ~~~~~~~~~~~~~~~~~~~~~~~
        Modules imports
    ~~~~~~~~~~~~~~~~~~~~~~~
*/
include { AMRFINDER_PLUS } from './modules/amrfinder_plus'
include { AMRFINDER_REPORT } from './modules/amrfinder_report'
include { CRISPR_FINDER } from './modules/crisprcas'
include { DIAMOND } from './modules/diamond'
include { FASTA_WRITER } from './modules/fasta_writer'
include { GBK_SPLITTER } from './modules/gbk_splitter'
include { GENOMAD } from './modules/genomad'
include { GFF_MAPPING } from './modules/gff_mapping'
include { GFF_REDUCE } from './modules/gff_reduce'
include { GFF_VALIDATOR } from './modules/validator'
include { INTEGRONFINDER } from './modules/integronfinder'
include { ISESCAN } from './modules/isescan'
include { ICEFINDER } from './modules/icefinder'
include { INTEGRATOR } from './modules/integrator'
include { PROKKA } from './modules/prokka'
include { RENAME } from './modules/rename_contigs'
include { VIRIFY_QC } from './modules/virify_qc'

/*
    ~~~~~~~~~~~~~~~~~~~~
        Help message    
    ~~~~~~~~~~~~~~~~~~~~
*/

def helpMessage() {
	log.info """
	The Mobilome Annotation Pipeline is a wrapper that integrates the output of different tools designed for the prediction of plasmids, phages and autonomous integrative mobile genetic elements in prokaryotic genomes and metagenomes. The output is PROKKA gff file with extra entries for the mobilome. The default tools to run are ISEScan (insertion sequences), IntegronFinder (integrons), geNomad (virus and plasmids), ICEfinder (ICE and IME), PROKKA (cds prediction and general functional annotation), Diamond vs MobileOG database (mobilome functions), AMRfinderplus (AMR annotation), and CRISPRCas (crispr arrays). In addition, the user can provide PaliDIS results to be integrated with ISEScan and VIRify v2.0 results to integrate with geNomad annotation. If the user have a CDS prediction, it can be used to generate an extra gff file with the option --user_genes. See usage below:

        Usage:
         The basic command for running the pipeline is as follows:

         nextflow run main.nf --assembly contigs.fasta

         Mandatory arguments:
          --assembly                      (Meta)genomic assembly in fasta format (uncompress)

         Optional arguments:
    ** Extra annotations provided by the user
        * Genes prediction  
          --user_genes                    Use the user annotation files. See --prot_gff [false]
          --prot_gff                      Annotation file in GFF3 format. Mandatory with '--user_genes true'
        * VIRify (v2.0)
          --virify                        Integrate VIRify v2.0 results to geNomad predictions [false]
          --vir_gff                       The final result of VIRify on gff format (08-final/gff/*.gff). Mandatory with '--virify true'
          --vir_checkv                    CheckV results generated by VIRify (07-checkv/*quality_summary.tsv). Mandatory with '--virify true'
        * PaliDIS (v2.3.4)
          --palidis                       Incorporate PaliDIS predictions to final output [false]
          --palidis_info                  Information file of PaliDIS insertion sequences. Mandatory with '--palidis true'
    ** Extra annotations inside the pipeline
          --skip_crispr                   Not to run CRISPRCasFinder. Default behaviour is to run it [false]
          --skip_amr                      Not to run AMRFinderPlus. Default behaviour is to run it [false]
    ** Final output validation
          --gff_validation                Validation of the GFF3 mobilome output [true]
    ** Output directory
          --outdir                        Output directory to place results [mobilome_results]
    ** Show usage message and exit
          --help                          This usage statement [false]
        """
}

if (params.help) {
	helpMessage()
	exit 0
}

/*
    ~~~~~~~~~~~~~~~~~~~~
        Run workflow
    ~~~~~~~~~~~~~~~~~~~~
*/

workflow {
	assembly = Channel.fromPath( params.assembly, checkIfExists: true )
	
	//PREPROCESSING
	RENAME( assembly )
	PROKKA( RENAME.out.contigs_1kb )


	// PREDICTION
	GENOMAD( RENAME.out.contigs_5kb )
	GBK_SPLITTER( PROKKA.out.prokka_gbk )
	ICEFINDER( 
		GBK_SPLITTER.out.gbks,
		file( "${params.outdir}/prediction/icefinder_results/gbk"),
		file( "${params.outdir}/prediction/icefinder_results/tmp"),
		file( "${params.outdir}/prediction/icefinder_results/result")
	)
	INTEGRONFINDER( RENAME.out.contigs_5kb )
	ISESCAN( RENAME.out.contigs_1kb )


	// ANNOTATION
	DIAMOND( PROKKA.out.prokka_faa, params.mobileog_db )
	if (params.virify){
		gff_input = Channel.fromPath( params.vir_gff, checkIfExists: true )
		checkv_input = file(params.vir_checkv, checkIfExists: true)
		VIRIFY_QC( gff_input, checkv_input )
		virify_results = VIRIFY_QC.out.virify_hq
	}else{
		virify_results = file('no_virify')
	}

	if (params.skip_crispr){
		crispr_tsv = file('no_crispr')
	}else{
		CRISPR_FINDER( RENAME.out.contigs_1kb )
		crispr_tsv = CRISPR_FINDER.out.crispr_report
	}
		
	if ( params.palidis ) {
		pal_info = Channel.fromPath( params.palidis_info, checkIfExists: true )
	}else{
		pal_info = file('no_info')
	}


	// INTEGRATION
	INTEGRATOR(
		PROKKA.out.prokka_gff, 
		RENAME.out.map_file, 
		ISESCAN.out.iss_tsv, 
		pal_info, 
		INTEGRONFINDER.out.inf_summ, 
		INTEGRONFINDER.out.inf_gbk.collect(), 
		ICEFINDER.out.icf_summ_files, 
		ICEFINDER.out.icf_dr, 
		DIAMOND.out.blast_out,
		GENOMAD.out.genomad_vir,
		GENOMAD.out.genomad_plas,
		virify_results,
		crispr_tsv,
	)


	// POSTPROCESSING
	GFF_REDUCE( INTEGRATOR.out.mobilome_prokka_gff )
	FASTA_WRITER( assembly, GFF_REDUCE.out.mobilome_nogenes )

	if ( params.user_genes ) {
		user_gff = Channel.fromPath( params.prot_gff, checkIfExists: true )
		GFF_MAPPING( GFF_REDUCE.out.mobilome_extra, user_gff )
	}

	if ( params.gff_validation ) {
		GFF_VALIDATOR( GFF_REDUCE.out.mobilome_nogenes )		
	}

	if ( !params.skip_amr ) {
		AMRFINDER_PLUS( PROKKA.out.prokka_fna, PROKKA.out.prokka_faa, PROKKA.out.prokka_gff )
		AMRFINDER_REPORT( AMRFINDER_PLUS.out.amrfinder_tsv, INTEGRATOR.out.mobilome_prokka_gff )
	}

}
