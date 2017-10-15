#' @name run_gstacks
#' @title Run STACKS new module called gstacks
#' @description Run \href{http://catchenlab.life.illinois.edu/stacks/}{STACKS}
#' \href{http://catchenlab.life.illinois.edu/stacks/stacks_v2.php}{gstacks}
#' module inside R!

#' @param P (path, character) De novo mode.
#' Path to the directory containing STACKS files.
#' Default: \code{P = "06_ustacks_cstacks_sstacks"}.
#' Inside the folder, you should have:
#' \itemize{
#'   \item \strong{the catalog files:} starting with \code{batch_} and ending with
#'   \code{.alleles.tsv.gz, .snps.tsv.gz, .tags.tsv.gz and .bam};
#'   \item \strong{5 files for each samples:} The sample name is the prefix for
#'   the files ending with:
#' \code{.alleles.tsv.gz, .models.tsv.gz, .snps.tsv.gz, .tags.tsv.gz and .bam}.
#' Those files are created in the
#' \href{http://catchenlab.life.illinois.edu/stacks/comp/ustacks.php}{ustacks},
#' \href{http://catchenlab.life.illinois.edu/stacks/comp/sstacks.php}{sstacks},
#' \href{http://catchenlab.life.illinois.edu/stacks/comp/cxstacks.php}{cxstacks},
#' \href{http://catchenlab.life.illinois.edu/stacks/stacks_v2.php}{tsv2bam}
#' modules
#' }.

#' @param b (integer) De novo mode. Database/batch ID of the input catalog
#' to consider. Advice: don't modify the default.
#' Default: \code{b = "guess"}.

#' @param B (character, path) Reference-based mode. Path to input BAM file.
#' The input BAM file should (i) be sorted by coordinate and (ii) comprise
#' all aligned reads for all samples, with reads assigned to samples using
#' BAM "reads groups" (gstacks uses the SN, "sample name" field).
#' Please refer to the gstacks manual page for information about how to
#' generate such a BAM file with Samtools or Sambamba, and examples.
#' Default: \code{B = NULL}.
#' @param O (character, path) Reference-based mode. Path to output directory.
#' Default: \code{O = NULL}.
#' @param paired (logical) Reference-based mode. True if reads are paired.
#' Note that the RAD loci will be defined by READ1 alignments.
#' Default: \code{paired = FALSE}.


#' @param t (integer) Enable parallel execution with the number of threads.
#' Default: \code{t = parallel::detectCores() - 1}.

#' @param details (logical) With default the function will write a more detailed
#' output.
#' Default: \code{details = TRUE}.

#' @param ignore.pe.reads (logical) With default the function will
#' ignore paired-end reads even if present in the input.
#' Default: \code{ignore.pe.reads = TRUE}.

#' @param model (character) The model to use to call variants and genotypes;
#' one of \code{"marukilow"}, \code{"marukihigh"}, or \code{"snp"}.
#' See ref for more details on algorithms.
#' Default: \code{model = "marukilow"}.
#' @param var.alpha (double) Alpha threshold for discovering SNPs.
#' Default: \code{var.alpha = 0.05}.
#' @param gt.alpha (double) Alpha threshold for calling genotypes.
#' Default: \code{gt.alpha = 0.05}.
#' @param kmer.length (integer) kmer length for the de Bruijn graph. For expert.
#' Default: \code{kmer.length = 31}.
#' @param min.kmer.cov (integer) Minimum coverage to consider a kmer. For exptert.
#' Default: \code{min.kmer.cov =2}.

#' @param h Display this help messsage.
#' Default: \code{h = FALSE}

#' @rdname run_gstacks
#' @export
#' @importFrom stringi stri_join stri_replace_all_fixed

#' @return \href{http://catchenlab.life.illinois.edu/stacks/stacks_v2.php}{tsv2bam}
#' returns a set of \code{.matches.bam} files.
#'
#' The function \code{run_gstacks} returns a list with the number of individuals, the batch ID number,
#' a summary data frame and a plot containing:
#' \enumerate{
#' \item INDIVIDUALS: the sample id
#' \item ALL_LOCUS: the total number of locus for the individual (shown in subplot A)
#' \item LOCUS: the number of locus with a one-to-one relationship (shown in subplot B)
#' with the catalog
#' \item MATCH_PERCENT: the percentage of locus with a one-to-one relationship
#' with the catalog (shown in subplot C)
#'
#' Addtionally, the function returns a batch_X.catalog.bam file that was generated
#' by merging all the individual BAM files in parallel.
#' }



#' @examples
#' \dontrun{
#' # The simplest form of the function with De novo data:
#' bam.sum <- stackr::run_gstacks() # that's it !
#' }

#' @seealso
#' \code{\link[stackr]{summary_tsv2bam}}
#'
#'\href{http://catchenlab.life.illinois.edu/stacks/}{STACKS}


#' @references Catchen JM, Amores A, Hohenlohe PA et al. (2011)
#' Stacks: Building and Genotyping Loci De Novo From Short-Read Sequences.
#' G3, 1, 171-182.
#' @references Catchen JM, Hohenlohe PA, Bassham S, Amores A, Cresko WA (2013)
#' Stacks: an analysis tool set for population genomics.
#' Molecular Ecology, 22, 3124-3140.
#' @references Maruki T, Lynch M (2017)
#' Genotype Calling from Population-Genomic Sequencing Data. G3, 7, 1393-1404.

run_gstacks <- function(
  P = "06_ustacks_cstacks_sstacks",
  b = "guess",
  B = NULL,
  O = NULL,
  paired = FALSE,
  t = parallel::detectCores() - 1,
  details = TRUE,
  ignore.pe.reads = TRUE,
  model = "marukilow",
  var.alpha = 0.05,
  gt.alpha = 0.05,
  kmer.length = 31,
  min.kmer.cov = 2,
  h = FALSE
  ) {

  cat("#######################################################################\n")
  cat("######################## stackr::run_gstacks ##########################\n")
  cat("#######################################################################\n")

  timing <- proc.time()

  # Check directory ------------------------------------------------------------
  if (!dir.exists("06_ustacks_cstacks_sstacks")) dir.create("06_ustacks_cstacks_sstacks")
  if (!dir.exists("09_log_files")) dir.create("09_log_files")
  if (!dir.exists("08_stacks_results")) dir.create("08_stacks_results")

  # file data and time ---------------------------------------------------------
  file.date.time <- stringi::stri_replace_all_fixed(
    str = Sys.time(),
    pattern = " EDT", replacement = "") %>%
    stringi::stri_replace_all_fixed(
      str = .,
      pattern = c("-", " ", ":"),
      replacement = c("", "@", ""),
      vectorize_all = FALSE
    ) %>%
    stringi::stri_sub(str = ., from = 1, to = 13)

  # logs file ------------------------------------------------------------------
  gstacks.log.file <- stringi::stri_join("09_log_files/gstacks_", file.date.time,".log")
  message("For progress, look in the log file:\n", gstacks.log.file)

  # gstacks arguments ----------------------------------------------------------

  # De novo approach -----------------------------------------------------------
  # Input filder path
  output.folder <- P # keep a distinct copy for other use
  P <- stringi::stri_join("-P ", shQuote(P))

  # Catalog batch ID
  if (b == "guess") {
    b <- ""
  } else {
    b <- stringi::stri_join("-b ", b)
  }


  # reference-based approach ---------------------------------------------------
  if (!is.null(B)) {
    B.bk <- B
    B <- stringi::stri_join("-B ", B)
    if (!is.null(O)) {
      O <- stringi::stri_join("-O ", O)
    } else {
      O <- B.bk
    }
    if (paired) {
      paired <- "--paired"
    } else {
      paired <- ""
    }
  } else {
    B <- ""
    O <- ""
    paired <- ""
  }



  # Shared options -------------------------------------------------------------

  # Threads
  parallel.core <- t # keep a distinct copy for other use
  t <- stringi::stri_join("-t ", t)

  # details
  if (details) {
    details <- "--details"
  } else {
    details <- ""
  }

  # paired-end
  ignore.pe.reads = TRUE
  if (ignore.pe.reads) {
    ignore.pe.reads <- "--ignore-pe-reads"
  } else {
    ignore.pe.reads <- ""
  }

  # Model options --------------------------------------------------------------
  model <- stringi::stri_join("--model ", model)
  var.alpha <- stringi::stri_join("--var-alpha ", var.alpha)
  gt.alpha <- stringi::stri_join("--gt-alpha ", gt.alpha)


  # Expert options -------------------------------------------------------------
  kmer.length <- stringi::stri_join("--kmer-length ", kmer.length)
  min.kmer.cov <- stringi::stri_join("--min-kmer-cov ", min.kmer.cov)

  # Help
  if (h) {
    h <- stringi::stri_join("-h ")
  } else {
    h <- ""
  }

  # command args ---------------------------------------------------------------
  command.arguments <- paste(
    P, b, B, O, paired, t, details, ignore.pe.reads, model, var.alpha, gt.alpha,
    kmer.length, min.kmer.cov, h)

  # run command ----------------------------------------------------------------
  system2(command = "gstacks", args = command.arguments, stderr = gstacks.log.file,
          stdout = gstacks.log.file)

  # summarize the log file -----------------------------------------------------
  timing <- proc.time() - timing
  message("\nComputation time: ", round(timing[[3]]), " sec")
  cat("########################## tsv2bam completed ##########################\n")
  res <- "gstacks finished"
  return(res)
}# end run_gstacks

