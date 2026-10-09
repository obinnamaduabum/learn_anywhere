package com.learnanywhere.config;

import io.smallrye.config.ConfigMapping;
import java.util.Optional;

@ConfigMapping(prefix = "learning")
public interface LearningConfig {
  Optional<String> adminToken();
  Optional<String> openaiKey();
  Optional<String> openaiModel();
  Optional<String> groqKey();
  Optional<String> groqModel();
}
