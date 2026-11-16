package com.carevora.controller;

import com.carevora.dto.ApiResponse;
import com.carevora.dto.memorygame.MemoryGameProgressSummaryResponse;
import com.carevora.dto.memorygame.MemoryGameSessionRequest;
import com.carevora.dto.memorygame.MemoryGameSessionResponse;
import com.carevora.service.MemoryGameService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/memory-games")
@RequiredArgsConstructor
@Tag(name = "Memory Games", description = "Endpoints for memory game session persistence and progress monitoring")
public class MemoryGameController {

    private final MemoryGameService memoryGameService;
    private final com.carevora.repository.ResidentRepository residentRepository;

    private static final Map<String, Map<String, Object>> ACTIVE_INVITES = new ConcurrentHashMap<>();

    @PostMapping("/sessions")
    @Operation(summary = "Persist a completed memory game session")
    public ResponseEntity<ApiResponse<MemoryGameSessionResponse>> saveGameSession(
            @Valid @RequestBody MemoryGameSessionRequest request
    ) {
        return ResponseEntity.ok(memoryGameService.saveGameSession(request));
    }

    @GetMapping("/resident/{residentId}")
    @Operation(summary = "Get historical completed memory game sessions for a resident")
    public ResponseEntity<ApiResponse<List<MemoryGameSessionResponse>>> getResidentGameSessions(
            @PathVariable Long residentId
    ) {
        return ResponseEntity.ok(memoryGameService.getResidentGameSessions(residentId));
    }

    @GetMapping("/resident/{residentId}/progress")
    @Operation(summary = "Get memory game progress summary and trends for a resident")
    public ResponseEntity<ApiResponse<MemoryGameProgressSummaryResponse>> getResidentGameProgress(
            @PathVariable Long residentId
    ) {
        return ResponseEntity.ok(memoryGameService.getResidentGameProgress(residentId));
    }

    @GetMapping("/elder-home/{elderHomeId}/elders")
    @Operation(summary = "Get fellow elders in the same Elder Home for collaborative game invites")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getEldersInHome(
            @PathVariable Long elderHomeId
    ) {
        List<Map<String, Object>> elders = residentRepository.findByElderHomeId(elderHomeId).stream()
                .map(r -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("residentId", r.getId());
                    map.put("name", r.getUser() != null ? r.getUser().getFullName() : "Resident #" + r.getId());
                    map.put("roomNumber", r.getRoomNumber() != null ? r.getRoomNumber() : "Suite");
                    map.put("elderHomeId", elderHomeId);
                    map.put("elderHomeName", r.getElderHome() != null ? r.getElderHome().getName() : "Elder Home");
                    return map;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(elders, "Facility elders retrieved"));
    }

    @PostMapping("/invites")
    @Operation(summary = "Send a collaborative memory game invite notification to a fellow elder")
    public ResponseEntity<ApiResponse<Map<String, Object>>> sendGameInvite(
            @RequestBody Map<String, Object> payload
    ) {
        String id = payload.getOrDefault("id", UUID.randomUUID().toString()).toString();
        Map<String, Object> invite = new HashMap<>(payload);
        invite.put("id", id);
        invite.put("status", "PENDING");
        invite.put("createdAt", System.currentTimeMillis());
        ACTIVE_INVITES.put(id, invite);
        return ResponseEntity.ok(ApiResponse.ok(invite, "Invitation sent to elder"));
    }

    @GetMapping("/invites")
    @Operation(summary = "Get active collaborative game invites for an Elder Home")
    public ResponseEntity<ApiResponse<List<Map<String, Object>>>> getGameInvites(
            @RequestParam(required = false) Long elderHomeId
    ) {
        List<Map<String, Object>> list = ACTIVE_INVITES.values().stream()
                .filter(inv -> {
                    if (elderHomeId == null) return true;
                    Object homeIdObj = inv.get("elderHomeId");
                    return homeIdObj != null && homeIdObj.toString().equals(elderHomeId.toString());
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(ApiResponse.ok(list, "Active invites retrieved"));
    }

    @PostMapping("/invites/{inviteId}/respond")
    @Operation(summary = "Accept or decline a collaborative memory game invite")
    public ResponseEntity<ApiResponse<Map<String, Object>>> respondToInvite(
            @PathVariable String inviteId,
            @RequestBody Map<String, Object> payload
    ) {
        Map<String, Object> invite = ACTIVE_INVITES.get(inviteId);
        if (invite != null) {
            String status = payload.getOrDefault("status", "ACCEPTED").toString().toUpperCase();
            invite.put("status", status);
        }
        return ResponseEntity.ok(ApiResponse.ok(invite, "Invite response recorded"));
    }
}
