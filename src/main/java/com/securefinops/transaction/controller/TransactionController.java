package com.securefinops.transaction.controller;

import com.securefinops.transaction.model.Transaction;
import com.securefinops.transaction.repository.TransactionRepository;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/transactions")
public class TransactionController {

    private final TransactionRepository repo;

    public TransactionController(TransactionRepository repo) {
        this.repo = repo;
    }

    @PostMapping
    public ResponseEntity<Transaction> create(@Valid @RequestBody Transaction t) {
        return ResponseEntity.status(201).body(repo.save(t));
    }

    @GetMapping
    public List<Transaction> getAll() {
        return repo.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Transaction> getById(@PathVariable Long id) {
        return repo.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}