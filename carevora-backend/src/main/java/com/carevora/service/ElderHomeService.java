package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.auth.FacilityAccessRequest;
import com.carevora.dto.elderhome.ElderHomeRequest;
import com.carevora.dto.elderhome.ElderHomeResponse;
import com.carevora.entity.Caregiver;
import com.carevora.entity.ElderHome;
import com.carevora.entity.Resident;
import com.carevora.exception.BadRequestException;
import com.carevora.exception.ResourceNotFoundException;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.ElderHomeRepository;
import com.carevora.repository.ResidentRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Random;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class ElderHomeService {

    private final ElderHomeRepository elderHomeRepository;
    private final ResidentRepository residentRepository;
    private final CaregiverRepository caregiverRepository;

    @Transactional(readOnly = true)
    public ApiResponse<List<ElderHomeResponse>> getAllElderHomes() {
        List<ElderHomeResponse> list = elderHomeRepository.findByActiveTrue().stream()
                .map(this::mapToResponse)
                .collect(Collectors.toList());
        return ApiResponse.ok(list);
    }

    @Transactional(readOnly = true)
    public ApiResponse<ElderHomeResponse> getElderHomeById(Long id) {
        ElderHome home = elderHomeRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Elder Home not found with id: " + id));
        return ApiResponse.ok(mapToResponse(home));
    }

    @Transactional(readOnly = true)
    public ApiResponse<List<java.util.Map<String, Object>>> getCaregiversByElderHomeId(Long elderHomeId) {
        List<Caregiver> caregivers = caregiverRepository.findByElderHomeIdWithUser(elderHomeId);
        List<java.util.Map<String, Object>> result = caregivers.stream()
                .filter(cg -> cg.getUser() != null && !Boolean.FALSE.equals(cg.getUser().getActive()))
                .map(cg -> {
                    java.util.Map<String, Object> item = new java.util.LinkedHashMap<>();
                    item.put("id", cg.getId());
                    item.put("name", cg.getUser().getFullName());
                    item.put("avatarUrl", cg.getUser().getAvatarUrl());
                    item.put("title", cg.getTitle());
                    item.put("department", cg.getDepartment());
                    item.put("staffCode", cg.getStaffCode());
                    item.put("elderHomeId", elderHomeId);
                    item.put("elderHomeName", cg.getElderHome() != null ? cg.getElderHome().getName() : null);
                    return item;
                })
                .collect(Collectors.toList());
        return ApiResponse.ok(result);
    }

    @Transactional
    public ApiResponse<ElderHomeResponse> registerElderHome(ElderHomeRequest request) {
        if (request.getName() == null || request.getName().trim().isEmpty()) {
            throw new BadRequestException("Elder home / facility name cannot be blank");
        }

        String code = request.getFacilityCode();
        if (code == null || code.trim().isEmpty()) {
            code = generateFacilityCode(request.getName());
        } else {
            code = code.trim().toUpperCase();
            if (elderHomeRepository.existsByFacilityCode(code)) {
                throw new BadRequestException("Facility code already in use: " + code);
            }
        }

        ElderHome home = ElderHome.builder()
                .name(request.getName().trim())
                .facilityCode(code)
                .address(request.getAddress())
                .contactEmail(request.getContactEmail())
                .contactPhone(request.getContactPhone())
                .active(true)
                .build();

        ElderHome saved = elderHomeRepository.save(home);
        return ApiResponse.ok(mapToResponse(saved), "Elder home facility registered successfully");
    }

    @Transactional
    public ApiResponse<ElderHomeResponse> requestFacilityAccess(FacilityAccessRequest request) {
        if (elderHomeRepository.existsByNameIgnoreCase(request.getFacilityName().trim())) {
            ElderHome existing = elderHomeRepository.findByName(request.getFacilityName().trim())
                    .orElseGet(() -> elderHomeRepository.findAll().get(0));
            return ApiResponse.ok(mapToResponse(existing), "Facility access request registered for existing facility");
        }

        String code = generateFacilityCode(request.getFacilityName());
        ElderHome home = ElderHome.builder()
                .name(request.getFacilityName().trim())
                .facilityCode(code)
                .address(request.getAddress() != null ? request.getAddress() : "Primary Care Facility")
                .contactEmail(request.getWorkEmail().trim())
                .contactPhone(request.getPhone())
                .active(true)
                .build();

        ElderHome saved = elderHomeRepository.save(home);
        return ApiResponse.ok(mapToResponse(saved), "Facility access request approved and created successfully");
    }

    @Transactional
    public ApiResponse<ElderHomeResponse> assignResident(Long elderHomeId, Long residentId) {
        ElderHome home = elderHomeRepository.findById(elderHomeId)
                .orElseThrow(() -> new ResourceNotFoundException("Elder Home not found with id: " + elderHomeId));
        Resident resident = residentRepository.findById(residentId)
                .orElseThrow(() -> new ResourceNotFoundException("Resident not found with id: " + residentId));

        resident.setElderHome(home);
        residentRepository.save(resident);
        return ApiResponse.ok(mapToResponse(home), "Resident assigned to " + home.getName());
    }

    @Transactional
    public ApiResponse<ElderHomeResponse> assignCaregiver(Long elderHomeId, Long caregiverId) {
        ElderHome home = elderHomeRepository.findById(elderHomeId)
                .orElseThrow(() -> new ResourceNotFoundException("Elder Home not found with id: " + elderHomeId));
        Caregiver caregiver = caregiverRepository.findById(caregiverId)
                .orElseThrow(() -> new ResourceNotFoundException("Caregiver not found with id: " + caregiverId));

        caregiver.setElderHome(home);
        caregiverRepository.save(caregiver);
        return ApiResponse.ok(mapToResponse(home), "Caregiver assigned to " + home.getName());
    }

    public ElderHomeResponse mapToResponse(ElderHome home) {
        long elderCount = residentRepository.countByElderHomeId(home.getId());
        long caregiverCount = caregiverRepository.countByElderHomeId(home.getId());

        return ElderHomeResponse.builder()
                .id(home.getId())
                .name(home.getName())
                .facilityCode(home.getFacilityCode())
                .address(home.getAddress())
                .contactEmail(home.getContactEmail())
                .contactPhone(home.getContactPhone())
                .active(home.getActive())
                .elderCount(elderCount)
                .caregiverCount(caregiverCount)
                .createdAt(home.getCreatedAt())
                .build();
    }

    private String generateFacilityCode(String name) {
        String prefix = name.replaceAll("[^a-zA-Z]", "").toUpperCase();
        if (prefix.length() > 3) {
            prefix = prefix.substring(0, 3);
        } else if (prefix.length() < 2) {
            prefix = "FAC";
        }
        int randomNum = 100 + new Random().nextInt(900);
        String code = prefix + "-" + randomNum;
        while (elderHomeRepository.existsByFacilityCode(code)) {
            randomNum = 100 + new Random().nextInt(900);
            code = prefix + "-" + randomNum;
        }
        return code;
    }
}
