#!/usr/bin/env nextflow

params {
    accession
    out
    in
}

process fetch_reference {
    publishDir "$params.out/reference"

    conda "bioconda::entrez-direct=24.0"
    container "https://depot.galaxyproject.org/singularity/entrez-direct:24.0--he881be0_0"

    input:
        val accession
    output:
        path "${accession}.fasta"
    script:
        """
        esearch -db nucleotide -query "$accession" | efetch -format fasta > "${accession}.fasta"
        """
}

process combine_samples {
    publishDir "$params.out/combined_samples"

    errorStrategy 'terminate'

    input: 
        path reference
        path samples
    output:
        path "${params.in}.combined.fasta"
    script:
        """
        if [ "${params.in}" == null ]; then
	        echo "ERROR: please provide a directory path using the --in parameter"
	        exit 1
        fi 
        cat *.* > "${params.in}.combined.fasta"
        """

}

process align {
    publishDir "${params.out}/alignment"

    conda "bioconda::mafft=7.525" // bioconda, biocore, conda-forge -- issues with Mac Silicon. Added config option. 

    input:
        path combined_sample
    output:
        path "${params.in}.aligned.fasta"
    script:
        """
        # mafft input > output 
        mafft "${combined_sample}" > "${params.in}.aligned.fasta"
        """
}

process clean_up {
    publishDir "${params.out}"

    conda "bioconda::trimal=1.5.0"

    input:
        path aligned
    output: 
        path "${params.in}.aligned_trimmed.fasta" 
        path "${params.in}.aligned_trimmed.html"
    script: 
        """
        trimal -automated1 -in "${aligned}" -out "${params.in}.aligned_trimmed.fasta" -htmlout "${params.in}.aligned_trimmed.html"
        """
}

workflow {
    def ch_ref = fetch_reference(params.accession)
    def ch_samples = channel.fromPath("$params.in/*.{fasta,fa,fas,fna}").collect()
    def ch_combine = combine_samples(ch_ref, ch_samples)
    def ch_align = align(ch_combine)
    def ch_clean = clean_up(ch_align)
}