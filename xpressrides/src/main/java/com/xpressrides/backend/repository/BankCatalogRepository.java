package com.xpressrides.backend.repository;

import com.xpressrides.backend.model.BankCatalog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface BankCatalogRepository extends JpaRepository<BankCatalog, String> {
    
    List<BankCatalog> findAllByOrderByNameAsc();

}
