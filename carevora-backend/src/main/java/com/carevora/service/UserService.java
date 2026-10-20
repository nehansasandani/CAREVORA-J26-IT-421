package com.carevora.service;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.user.UserSummaryResponse;
import com.carevora.entity.Caregiver;
import com.carevora.entity.Resident;
import com.carevora.entity.User;
import com.carevora.enums.UserRole;
import com.carevora.repository.CaregiverRepository;
import com.carevora.repository.ResidentRepository;
import com.carevora.repository.UserRepository;
import com.carevora.security.SecurityUtils;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final ResidentRepository residentRepository;
    private final CaregiverRepository caregiverRepository;

    @Transactional(readOnly = true)
    public ApiResponse<List<UserSummaryResponse>> getAllUsersForDoctor(String search) {
        User currentUser = SecurityUtils.getCurrentUser(userRepository)
                .orElseThrow(() -> new AccessDeniedException("Authentication required"));

        if (currentUser.getRole() != UserRole.DOCTOR && currentUser.getRole() != UserRole.ADMIN) {
            throw new AccessDeniedException("Access denied: Only clinical doctors and administrators are authorized to view all users directory.");
        }

        List<User> users = userRepository.findAll();
        if (search != null && !search.trim().isEmpty()) {
            String q = search.trim().toLowerCase();
            users = users.stream().filter(u ->
                    u.getFullName().toLowerCase().contains(q) ||
                    u.getEmail().toLowerCase().contains(q) ||
                    u.getRole().name().toLowerCase().contains(q)
            ).collect(Collectors.toList());
        }

        List<UserSummaryResponse> responses = users.stream().map(u -> {
            Optional<Resident> resOpt = residentRepository.findByUserId(u.getId());
            Optional<Caregiver> cgOpt = caregiverRepository.findByUserId(u.getId());

            Long homeId = null;
            String homeName = null;
            Long resId = null;
            Long cgId = null;
            String room = null;
            Integer age = null;
            com.carevora.enums.WellnessStatus status = null;
            com.carevora.enums.RiskLevel risk = null;
            String staffCode = null;
            String title = null;
            String dept = null;

            Integer eduYears = null;
            if (resOpt.isPresent()) {
                Resident r = resOpt.get();
                resId = r.getId();
                room = r.getRoomNumber();
                age = r.getAge();
                eduYears = r.getEducationYears();
                status = r.getCurrentStatus();
                risk = r.getRiskLevel();
                if (r.getElderHome() != null) {
                    homeId = r.getElderHome().getId();
                    homeName = r.getElderHome().getName();
                }
            } else if (cgOpt.isPresent()) {
                Caregiver cg = cgOpt.get();
                cgId = cg.getId();
                staffCode = cg.getStaffCode();
                title = cg.getTitle();
                dept = cg.getDepartment();
                if (cg.getElderHome() != null) {
                    homeId = cg.getElderHome().getId();
                    homeName = cg.getElderHome().getName();
                }
            } else if (u.getRole() == UserRole.DOCTOR) {
                title = "Consulting Clinical Specialist / Doctor";
                dept = "Geriatric Clinical Care";
            }

            UserSummaryResponse resp = new UserSummaryResponse();
            resp.setId(u.getId());
            resp.setName(u.getFullName());
            resp.setEmail(u.getEmail());
            resp.setRole(u.getRole());
            resp.setActive(u.getActive());
            resp.setAvatarUrl(u.getAvatarUrl());
            resp.setElderHomeId(homeId);
            resp.setElderHomeName(homeName);
            resp.setResidentId(resId);
            resp.setCaregiverId(cgId);
            resp.setRoomNumber(room);
            resp.setAge(age);
            resp.setEducationYears(eduYears);
            resp.setCurrentStatus(status);
            resp.setRiskLevel(risk);
            resp.setStaffCode(staffCode);
            resp.setTitle(title);
            resp.setDepartment(dept);
            resp.setCreatedAt(u.getCreatedAt());
            return resp;
        }).collect(Collectors.toList());

        return ApiResponse.ok(responses);
    }
}
