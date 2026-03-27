from pyspark import SparkConf, SparkContext
import sys

conf = SparkConf().setAppName("WordCount").setMaster("local[*]")
sc = SparkContext(conf=conf)
sc.setLogLevel("WARN")

input_path = sys.argv[1] if len(sys.argv) > 1 else "input.txt"

counts = (
    sc.textFile(input_path)
      .flatMap(lambda line: line.lower().split())
      .filter(lambda w: len(w) > 0)
      .map(lambda word: (word, 1))
      .reduceByKey(lambda a, b: a + b)
      .sortBy(lambda x: x[1], ascending=False)
)

for word, count in counts.collect():
    print(f"{word}\t{count}")

sc.stop()
