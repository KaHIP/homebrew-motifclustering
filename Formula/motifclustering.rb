class Motifclustering < Formula
  desc "Combinatorial algorithms for local motif clustering in graphs"
  homepage "https://github.com/LocalClustering/HeidelbergMotifClustering"
  url "https://github.com/LocalClustering/HeidelbergMotifClustering/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "b46685c9c6e54931e40429a35acf279459c4587be8430586ca869dffa5ff0811"
  license "MIT"
  head "https://github.com/LocalClustering/HeidelbergMotifClustering.git", branch: "master"

  depends_on "cmake" => :build
  depends_on "gcc" => :build

  def install
    gcc = Formula["gcc"]
    gcc_version = gcc.version.major

    cmake_args = std_cmake_args.reject { |a| a.start_with?("-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=") }
    cmake_args += %W[
      -DCMAKE_BUILD_TYPE=Release
      -DCMAKE_C_COMPILER=#{gcc.opt_bin}/gcc-#{gcc_version}
      -DCMAKE_CXX_COMPILER=#{gcc.opt_bin}/g++-#{gcc_version}
      -DNONATIVEOPTIMIZATIONS=ON
    ]

    # Build SOCIAL (recommended algorithm, no MPI needed)
    system "cmake", "-B", "build_social", "-S", "SOCIAL", *cmake_args
    system "cmake", "--build", "build_social", "-j#{ENV.make_jobs}"

    bin.install "build_social/social"
    bin.install "build_social/triangle_counter"
    bin.install "build_social/evaluator" => "motif_evaluator"

    # Build LMCHGP (patch MPI to optional — not actually linked)
    inreplace "LMCHGP/CMakeLists.txt", "find_package(MPI REQUIRED)", "find_package(MPI)"
    system "cmake", "-B", "build_lmchgp", "-S", "LMCHGP", *cmake_args
    system "cmake", "--build", "build_lmchgp", "-j#{ENV.make_jobs}"

    bin.install "build_lmchgp/motif_clustering_graph"

    # Install wrapper script with paths adjusted for Homebrew
    wrapper = buildpath/"heidelberg_motif_clustering"
    inreplace wrapper, /^SCRIPT_DIR=.*$/, "SCRIPT_DIR=\"#{bin}\""
    inreplace wrapper, "BINARY=\"$SCRIPT_DIR/SOCIAL/deploy/social\"", "BINARY=\"$SCRIPT_DIR/social\""
    inreplace wrapper, "TRIANGLE_COUNTER=\"$SCRIPT_DIR/SOCIAL/deploy/triangle_counter\"", "TRIANGLE_COUNTER=\"$SCRIPT_DIR/triangle_counter\""
    inreplace wrapper, "BINARY=\"$SCRIPT_DIR/LMCHGP/deploy/motif_clustering_graph\"", "BINARY=\"$SCRIPT_DIR/motif_clustering_graph\""
    bin.install "heidelberg_motif_clustering"

    # Install examples
    pkgshare.install Dir["examples/*"]
  end

  test do
    (testpath/"test.graph").write <<~EOS
      7 12
      2 3 7
      1 3 4 5
      1 2 4 5
      2 3 5 6 7
      2 3 4
      4 7
      1 4 6
    EOS
    output = shell_output("#{bin}/heidelberg_motif_clustering --algorithm social --graph #{testpath}/test.graph --seed_node 1 2>&1")
    assert_match "Motif Conductance", output
  end
end
