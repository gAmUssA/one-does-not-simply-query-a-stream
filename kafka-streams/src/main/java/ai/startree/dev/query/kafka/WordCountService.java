package ai.startree.dev.query.kafka;

import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;

import static spark.Spark.get;
import static spark.Spark.port;

public class WordCountService {

  public static void startRestService(KafkaStreams streams) {
    //TODO - configurable (?)
    port(8081);

    get("/words/:word", (req, res) -> {
      String word = req.params(":word");
      ReadOnlyKeyValueStore<String, Long> keyValueStore =
          streams.store(StoreQueryParameters.fromNameAndType("word-counts-store", QueryableStoreTypes.keyValueStore()));

      Long count = keyValueStore.get(word);
      if (count == null) {
        res.status(404);
        return "Word not found";
      }
      res.type("application/json");
      return "{\"word\":\"" + word + "\", \"count\":" + count + "}";
    });
  }
}