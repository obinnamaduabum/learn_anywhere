package com.learnanywhere.service;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.List;

// Optional provider integration. Free ChatGPT content is imported manually.
public interface IContentGenerator {
  JsonNode generate(String subject, List<String> topics, String language, String format);
}
