process GENOMAD {

    publishDir "${params.outdir}/prediction/", mode: 'copy'

    container 'quay.io/biocontainers/genomad:1.6.1--pyhdfd78af_0'

    input:
    tuple val(meta), path(assembly_file)

    output:
    tuple val(meta), path("genomad_out/5kb_contigs_summary/5kb_contigs_virus_summary.tsv"), emit: genomad_vir
    tuple val(meta), path("genomad_out/5kb_contigs_summary/5kb_contigs_plasmid_summary.tsv"), emit: genomad_plas

    script:
    """    
    genomad end-to-end ${assembly_file} \
    --threads ${task.cpus} \
    genomad_out ${params.genomad_db}
    """
}
