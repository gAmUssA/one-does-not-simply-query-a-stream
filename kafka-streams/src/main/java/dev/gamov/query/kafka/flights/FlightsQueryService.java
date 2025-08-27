package dev.gamov.query.kafka.flights;

import com.fasterxml.jackson.databind.ObjectMapper;

import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.StoreQueryParameters;
import org.apache.kafka.streams.state.KeyValueIterator;
import org.apache.kafka.streams.state.QueryableStoreTypes;
import org.apache.kafka.streams.state.ReadOnlyKeyValueStore;

import java.util.HashMap;
import java.util.Map;

import io.confluent.developer.models.flight.Flight;
import io.javalin.Javalin;
import io.javalin.http.staticfiles.Location;

public class FlightsQueryService {

  private static final ObjectMapper MAPPER = new ObjectMapper();

  public static void start(KafkaStreams streams) {
    int port = Integer.parseInt(System.getenv().getOrDefault("FLIGHTS_QUERY_PORT", "9100"));
    Javalin app = Javalin.create(config -> {
      config.showJavalinBanner = false;
      // Serve static files from classpath:/public
      config.staticFiles.add(staticFiles -> {
        staticFiles.hostedPath = "/"; // root
        staticFiles.directory = "/public"; // src/main/resources/public
        staticFiles.location = Location.CLASSPATH;
        staticFiles.precompress = false;
      });
    }).start(port);

    // Root redirects to the UI
    app.get("/", ctx -> ctx.redirect("/index.html"));

    app.get("/flights/{flightNumber}", ctx -> {
      String flightNumber = ctx.pathParam("flightNumber");
      ReadOnlyKeyValueStore<String, Flight> store =
          streams.store(StoreQueryParameters.fromNameAndType("flights-store", QueryableStoreTypes.keyValueStore()));

      Flight flight = store.get(flightNumber);
      if (flight == null) {
        ctx.status(404);
        ctx.contentType("application/json");
        ctx.result(MAPPER.writeValueAsString(Map.of("error", "Flight not found")));
        return;
      }

      Map<String, Object> dto = new HashMap<>();
      dto.put("flightNumber", flight.getFlightNumber());
      dto.put("airline", flight.getAirline());
      dto.put("origin", flight.getOrigin());
      dto.put("destination", flight.getDestination());
      dto.put("scheduledDeparture", flight.getScheduledDeparture());
      dto.put("actualDeparture", flight.getActualDeparture());
      dto.put("status", flight.getStatus());

      ctx.contentType("application/json");
      ctx.result(MAPPER.writeValueAsString(dto));
    });

    // Get delayed count for a specific airport (origin)
    app.get("/airports/{code}/delayed", ctx -> {
      String code = ctx.pathParam("code");
      ReadOnlyKeyValueStore<String, Long> store =
          streams.store(StoreQueryParameters.fromNameAndType("delayed-by-origin-store", QueryableStoreTypes.keyValueStore()));
      Long count = store.get(code);
      if (count == null) count = 0L;
      ctx.contentType("application/json");
      ctx.result(MAPPER.writeValueAsString(Map.of("airport", code, "delayedCount", count)));
    });

    // Get delayed counts for all airports
    app.get("/airports/delayed", ctx -> {
      ReadOnlyKeyValueStore<String, Long> store =
          streams.store(StoreQueryParameters.fromNameAndType("delayed-by-origin-store", QueryableStoreTypes.keyValueStore()));
      Map<String, Long> result = new HashMap<>();
      try (KeyValueIterator<String, Long> it = store.all()) {
        while (it.hasNext()) {
          var kv = it.next();
          result.put(kv.key, kv.value);
        }
      }
      ctx.contentType("application/json");
      ctx.result(MAPPER.writeValueAsString(result));
    });
  }
}
