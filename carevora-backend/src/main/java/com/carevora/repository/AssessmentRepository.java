package com.carevora.repository;

import com.carevora.entity.Assessment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface AssessmentRepository extends JpaRepository<Assessment, Long> {
    List<Assessment> findByResidentIdOrderByCreatedAtDescIdDesc(Long residentId);
    default List<Assessment> findByResidentIdOrderByCreatedAtDesc(Long residentId) {
        return findByResidentIdOrderByCreatedAtDescIdDesc(residentId);
    }
    List<Assessment> findTop10ByOrderByCreatedAtDesc();
}
