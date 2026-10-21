package com.carevora.repository;

import com.carevora.entity.MetabolicAssessment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface MetabolicAssessmentRepository extends JpaRepository<MetabolicAssessment, Long> {
    List<MetabolicAssessment> findByResidentIdOrderByCreatedAtDesc(Long residentId);
    Optional<MetabolicAssessment> findFirstByResidentIdOrderByCreatedAtDesc(Long residentId);
    Page<MetabolicAssessment> findByResidentId(Long residentId, Pageable pageable);
    List<MetabolicAssessment> findByResidentIdAndCreatedAtLessThanEqual(
            Long residentId, LocalDateTime createdAt, Pageable pageable);
    Page<MetabolicAssessment> findByResidentIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(
            Long residentId, LocalDateTime from, LocalDateTime toExclusive, Pageable pageable);
}
