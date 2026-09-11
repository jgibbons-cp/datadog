package com.demo.orders;

import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * Reads failure-injection flags from Redis so the operator control panel can
 * flip scenarios on and off live, without restarting any service.
 */
@Component
public class ChaosFlags {

    private static final Logger log = LoggerFactory.getLogger(ChaosFlags.class);
    private final JedisPool pool;

    public ChaosFlags(@Value("${chaos.redis-host}") String host,
                      @Value("${chaos.redis-port}") int port) {
        JedisPoolConfig cfg = new JedisPoolConfig();
        cfg.setMaxTotal(16);
        this.pool = new JedisPool(cfg, host, port, 2000);
    }

    public boolean on(String flag) {
        return "1".equals(get("chaos:" + flag));
    }

    public int intFlag(String flag, int fallback) {
        String v = get("chaos:" + flag);
        if (v == null || v.isBlank()) return fallback;
        try {
            return Integer.parseInt(v.trim());
        } catch (NumberFormatException e) {
            return fallback;
        }
    }

    private String get(String key) {
        try (Jedis j = pool.getResource()) {
            return j.get(key);
        } catch (Exception e) {
            log.warn("chaos flag lookup failed for {}: {}", key, e.getMessage());
            return null;
        }
    }

    @PreDestroy
    public void close() {
        pool.close();
    }
}
