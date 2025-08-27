package dev.gamov.query.kafka.movies;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;

import java.util.Map;

import io.javalin.Javalin;

public class WordCountService {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  public static void startRestService(KafkaStreams streams) {
    int port = Integer.parseInt(System.getenv().getOrDefault("WORDCOUNT_QUERY_PORT", "9091"));
    Javalin app = Javalin.create(config -> config.showJavalinBanner = true).start(port);

    app.get("/words/{word}", ctx -> {
      String word = ctx.pathParam("word");
      ReadOnlyKeyValueStore<String, Long> keyValueStore =
          streams.store(StoreQueryParameters.fromNameAndType("word-counts-store", QueryableStoreTypes.keyValueStore()));

      Long count = keyValueStore.get(word);
      if (count == null) {
        ctx.status(404);
        ctx.contentType("application/json");
        ctx.result(MAPPER.writeValueAsString(Map.of("error", "Word not found")));
        return;
      }
      ctx.contentType("application/json");
      ctx.result(MAPPER.writeValueAsString(Map.of("word", word, "count", count)));
    });
  }
}