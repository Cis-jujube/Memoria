package com.jujube.memoria.ui;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.PointF;
import android.graphics.RadialGradient;
import android.graphics.RectF;
import android.graphics.Shader;
import android.view.View;

import com.jujube.memoria.data.RelationshipEdge;

import java.util.ArrayList;
import java.util.List;
import java.util.TreeSet;

public final class RelationshipMapCanvas extends View {
    private final List<RelationshipEdge> edges;
    private final Paint linePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint nodePaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint orbitPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint centerPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint haloPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint textPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Paint initialsPaint = new Paint(Paint.ANTI_ALIAS_FLAG);

    public RelationshipMapCanvas(Context context, List<RelationshipEdge> edges) {
        super(context);
        this.edges = edges;
        setMinimumHeight(Ui.dp(context, 260));
        setLayerType(View.LAYER_TYPE_SOFTWARE, null);
        linePaint.setStrokeWidth(Ui.dp(context, 2));
        orbitPaint.setStyle(Paint.Style.STROKE);
        orbitPaint.setStrokeWidth(Ui.dp(context, 1));
        orbitPaint.setColor(0x66EEF2EF);
        centerPaint.setColor(0xFFFFFFFF);
        haloPaint.setStyle(Paint.Style.FILL);
        nodePaint.setColor(Ui.INK);
        textPaint.setColor(0xFFEAF2ED);
        textPaint.setTextSize(Ui.dp(context, 12));
        textPaint.setTextAlign(Paint.Align.CENTER);
        initialsPaint.setColor(Ui.INK);
        initialsPaint.setTextSize(Ui.dp(context, 12));
        initialsPaint.setFakeBoldText(true);
        initialsPaint.setTextAlign(Paint.Align.CENTER);
    }

    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        List<String> names = nodeNames();
        List<PointF> points = nodePoints(names.size());
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f - Ui.dp(getContext(), 2);

        Paint backgroundPaint = new Paint(Paint.ANTI_ALIAS_FLAG);
        backgroundPaint.setShader(new RadialGradient(
                centerX,
                centerY,
                Math.max(getWidth(), getHeight()) * 0.72f,
                new int[]{0xFF2A624B, 0xFF17372D, 0xFF081410},
                new float[]{0f, 0.46f, 1f},
                Shader.TileMode.CLAMP
        ));
        canvas.drawRoundRect(
                0,
                0,
                getWidth(),
                getHeight(),
                Ui.dp(getContext(), 8),
                Ui.dp(getContext(), 8),
                backgroundPaint
        );

        drawOrbits(canvas, names.size(), centerX, centerY);

        for (RelationshipEdge edge : edges) {
            int start = names.indexOf(edge.sourceName);
            int end = names.indexOf(edge.targetName);
            if (start < 0 || end < 0) {
                continue;
            }

            int alpha = Math.max(88, (int) (edge.strength * 230));
            linePaint.setStrokeWidth(Ui.dp(getContext(), (float) (1.4 + edge.strength * 2.8)));
            linePaint.setColor((alpha << 24) | (0xFFEAF2ED & 0x00FFFFFF));
            PointF startPoint = points.get(start);
            PointF endPoint = points.get(end);
            canvas.drawLine(centerX, centerY, startPoint.x, startPoint.y, linePaint);
            canvas.drawLine(centerX, centerY, endPoint.x, endPoint.y, linePaint);
            canvas.drawLine(startPoint.x, startPoint.y, endPoint.x, endPoint.y, linePaint);
        }

        float centerRadius = Ui.dp(getContext(), 34);
        centerPaint.setShadowLayer(Ui.dp(getContext(), 24), 0, 0, 0xBB8ACF9A);
        canvas.drawCircle(centerX, centerY, centerRadius, centerPaint);
        initialsPaint.setColor(Ui.INK);
        initialsPaint.setTextSize(Ui.dp(getContext(), 13));
        canvas.drawText("ME", centerX, centerY + Ui.dp(getContext(), 5), initialsPaint);

        for (int index = 0; index < names.size(); index += 1) {
            PointF point = points.get(index);
            String name = names.get(index);
            float strength = strengthFor(name);
            float radius = Ui.dp(getContext(), 21 + strength * 9);
            haloPaint.setColor((int) (0x55 + strength * 0x66) << 24 | (Ui.SAGE & 0x00FFFFFF));
            haloPaint.setShadowLayer(Ui.dp(getContext(), 12 + strength * 20), 0, 0, (0xCC << 24) | (Ui.SAGE & 0x00FFFFFF));
            canvas.drawCircle(point.x, point.y, radius + Ui.dp(getContext(), 5), haloPaint);
            nodePaint.setShader(new LinearGradient(
                    point.x - radius,
                    point.y - radius,
                    point.x + radius,
                    point.y + radius,
                    0xFFFFFFFF,
                    Ui.SAGE,
                    Shader.TileMode.CLAMP
            ));
            canvas.drawCircle(point.x, point.y, radius, nodePaint);
            nodePaint.setShader(null);
            initialsPaint.setColor(Ui.INK);
            initialsPaint.setTextSize(Ui.dp(getContext(), 12));
            canvas.drawText(initials(name), point.x, point.y + Ui.dp(getContext(), 4), initialsPaint);
            canvas.drawText(name, point.x, point.y + radius + Ui.dp(getContext(), 18), textPaint);
        }
    }

    private List<String> nodeNames() {
        TreeSet<String> names = new TreeSet<>();
        for (RelationshipEdge edge : edges) {
            names.add(edge.sourceName);
            names.add(edge.targetName);
        }
        return new ArrayList<>(names);
    }

    private List<PointF> nodePoints(int count) {
        List<PointF> points = new ArrayList<>();
        float centerX = getWidth() / 2f;
        float centerY = getHeight() / 2f - Ui.dp(getContext(), 2);
        float radiusX = Math.max(82, Math.min(getWidth(), getHeight()) / 2f - Ui.dp(getContext(), 52));
        float radiusY = radiusX * 0.48f;

        for (int index = 0; index < count; index += 1) {
            double angle = ((double) index / Math.max(count, 1)) * Math.PI * 2 - Math.PI / 2;
            points.add(new PointF(
                    centerX + (float) Math.cos(angle) * radiusX,
                    centerY + (float) Math.sin(angle) * radiusY
            ));
        }

        return points;
    }

    private void drawOrbits(Canvas canvas, int count, float centerX, float centerY) {
        float maxRadius = Math.max(82, Math.min(getWidth(), getHeight()) / 2f - Ui.dp(getContext(), 52));
        int orbitCount = Math.max(2, Math.min(4, count));

        for (int index = 1; index <= orbitCount; index += 1) {
            float radiusX = maxRadius * (0.45f + index * 0.17f);
            float radiusY = radiusX * 0.48f;
            orbitPaint.setAlpha(80 + index * 24);
            canvas.drawOval(
                    new RectF(centerX - radiusX, centerY - radiusY, centerX + radiusX, centerY + radiusY),
                    orbitPaint
            );
        }
    }

    private float strengthFor(String name) {
        double total = 0;
        int count = 0;

        for (RelationshipEdge edge : edges) {
            if (name.equals(edge.sourceName) || name.equals(edge.targetName)) {
                total += edge.strength;
                count += 1;
            }
        }

        if (count == 0) {
            return 0.7f;
        }

        return (float) Math.max(0.5, Math.min(0.96, total / count));
    }

    private static String initials(String name) {
        String[] parts = name.trim().split("\\s+");
        StringBuilder builder = new StringBuilder();
        for (int index = 0; index < Math.min(2, parts.length); index += 1) {
            if (!parts[index].isEmpty()) {
                builder.append(parts[index].charAt(0));
            }
        }
        return builder.toString();
    }
}
