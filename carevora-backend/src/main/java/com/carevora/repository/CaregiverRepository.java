package com.carevora.repository;

import com.carevora.entity.Caregiver;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface CaregiverRepository extends JpaRepository<Caregiver, Long> {
    Optional<Caregiver> findByUserId(Long userId);
    Optional<Caregiver> findByStaffCode(String staffCode);
    java.util.List<Caregiver> findByElderHomeId(Long elderHomeId);

    @Query("SELECT c FROM Caregiver c JOIN FETCH c.user LEFT JOIN FETCH c.elderHome WHERE c.elderHome.id = :elderHomeId")
    java.util.List<Caregiver> findByElderHomeIdWithUser(@Param("elderHomeId") Long elderHomeId);

    long countByElderHomeId(Long elderHomeId);
}
