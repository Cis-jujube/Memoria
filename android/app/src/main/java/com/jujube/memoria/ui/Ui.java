package com.jujube.memoria.ui;

import android.content.Context;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.TextView;

public final class Ui {
    public static final int INK = 0xFF0A231C;
    public static final int PANEL = 0xFF17372D;
    public static final int CANVAS = 0xFFEEF2EF;
    public static final int CARD = 0xFFFFFFFF;
    public static final int MUTED = 0xFF66736C;
    public static final int SAGE = 0xFF78937E;
    public static final int GOLD = 0xFFC8A551;
    public static final int BORDER = 0x1A000000;

    private Ui() {
    }

    public static int dp(Context context, float value) {
        return (int) TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_DIP,
                value,
                context.getResources().getDisplayMetrics()
        );
    }

    public static TextView text(Context context, String value, float sp, int color, int style) {
        TextView view = new TextView(context);
        view.setText(value);
        view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        view.setTextColor(color);
        view.setTypeface(Typeface.DEFAULT, style);
        view.setIncludeFontPadding(true);
        return view;
    }

    public static GradientDrawable rounded(int color, float radiusDp, Context context) {
        GradientDrawable drawable = new GradientDrawable();
        drawable.setColor(color);
        drawable.setCornerRadius(dp(context, radiusDp));
        return drawable;
    }

    public static GradientDrawable roundedStroke(int color, float radiusDp, int strokeColor, Context context) {
        GradientDrawable drawable = rounded(color, radiusDp, context);
        drawable.setStroke(dp(context, 1), strokeColor);
        return drawable;
    }

    public static LinearLayout vertical(Context context, int spacingDp) {
        LinearLayout layout = new LinearLayout(context);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setDividerPadding(dp(context, spacingDp));
        return layout;
    }

    public static LinearLayout horizontal(Context context) {
        LinearLayout layout = new LinearLayout(context);
        layout.setOrientation(LinearLayout.HORIZONTAL);
        layout.setGravity(Gravity.CENTER_VERTICAL);
        return layout;
    }

    public static void pad(View view, int allDp) {
        int padding = dp(view.getContext(), allDp);
        view.setPadding(padding, padding, padding, padding);
    }

    public static void pad(View view, int horizontalDp, int verticalDp) {
        int horizontal = dp(view.getContext(), horizontalDp);
        int vertical = dp(view.getContext(), verticalDp);
        view.setPadding(horizontal, vertical, horizontal, vertical);
    }

    public static LinearLayout.LayoutParams matchWrap() {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
        );
    }

    public static LinearLayout.LayoutParams matchWeight(float weight) {
        return new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                0,
                weight
        );
    }
}
