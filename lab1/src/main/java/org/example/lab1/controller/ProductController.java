package org.example.lab1.controller;

import org.example.lab1.model.Product;
import org.example.lab1.service.ProductService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class ProductController {
    @Autowired
    private ProductService productService;

    @Autowired
    private Environment environment;

    @GetMapping("/products")
    public Map<String, Object> getProducts() {
        List<Product> products = productService.getAllProducts();
        String port = environment.getProperty("local.server.port");
        String instanceId = environment.getProperty("INSTANCE_ID", "unknown");

        Map<String, Object> response = new HashMap<>();
        response.put("server_port", port != null ? port : "unknown");
        response.put("instance_id", instanceId);
        response.put("data", products);
        return response;
    }
}
